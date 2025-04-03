;; peer-verification.clar
;; Leverages community knowledge for claims validation

(define-data-var admin principal tx-sender)

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_CLAIM_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_VERIFIED (err u102))
(define-constant ERR_VERIFICATION_LIMIT (err u103))

;; Verification status
(define-constant STATUS_PENDING u0)
(define-constant STATUS_APPROVED u1)
(define-constant STATUS_REJECTED u2)

;; Claim verification data structure
(define-map claim-verifications
  { claim-id: uint }
  {
    status: uint,
    verifications-required: uint,
    approvals: uint,
    rejections: uint,
    verifiers: (list 20 principal)
  }
)

;; Track who has verified which claims
(define-map verifier-history
  { claim-id: uint, verifier: principal }
  { verified: bool, approved: bool }
)

;; Initialize a new claim for verification
(define-public (initialize-claim-verification (claim-id uint) (verifications-required uint))
  (begin
    (asserts! (or (is-eq tx-sender (var-get admin)) (is-authorized)) ERR_UNAUTHORIZED)
    (map-insert claim-verifications
      { claim-id: claim-id }
      {
        status: STATUS_PENDING,
        verifications-required: verifications-required,
        approvals: u0,
        rejections: u0,
        verifiers: (list)
      }
    )
    (ok true)
  )
)

;; Verify a claim
(define-public (verify-claim (claim-id uint) (approve bool))
  (let (
    (verification (map-get? claim-verifications { claim-id: claim-id }))
    (verifier-record (map-get? verifier-history { claim-id: claim-id, verifier: tx-sender }))
  )
    ;; Check if claim exists
    (asserts! (is-some verification) ERR_CLAIM_NOT_FOUND)
    ;; Check if verifier has already verified
    (asserts! (is-none verifier-record) ERR_ALREADY_VERIFIED)

    (let (
      (current-verification (unwrap-panic verification))
      (current-verifiers (get verifiers current-verification))
      (current-approvals (get approvals current-verification))
      (current-rejections (get rejections current-verification))
      (required-verifications (get verifications-required current-verification))
    )
      ;; Check if we've reached the verification limit
      (asserts! (< (+ current-approvals current-rejections) required-verifications) ERR_VERIFICATION_LIMIT)

      ;; Record this verification
      (map-insert verifier-history
        { claim-id: claim-id, verifier: tx-sender }
        { verified: true, approved: approve }
      )

      ;; Update verification counts
      (let (
        (new-approvals (if approve (+ current-approvals u1) current-approvals))
        (new-rejections (if (not approve) (+ current-rejections u1) current-rejections))
        (new-verifiers (unwrap-panic (as-max-len? (append current-verifiers tx-sender) u20)))
        (new-status (determine-status new-approvals new-rejections required-verifications))
      )
        (map-set claim-verifications
          { claim-id: claim-id }
          {
            status: new-status,
            verifications-required: required-verifications,
            approvals: new-approvals,
            rejections: new-rejections,
            verifiers: new-verifiers
          }
        )
        (ok new-status)
      )
    )
  )
)

;; Helper to determine status based on verification counts
(define-private (determine-status (approvals uint) (rejections uint) (required uint))
  (if (>= approvals (/ (+ required u1) u2))
    STATUS_APPROVED
    (if (>= rejections (/ (+ required u1) u2))
      STATUS_REJECTED
      STATUS_PENDING
    )
  )
)

;; Get verification status
(define-read-only (get-verification-status (claim-id uint))
  (let ((verification (map-get? claim-verifications { claim-id: claim-id })))
    (if (is-some verification)
      (ok (get status (unwrap-panic verification)))
      (err ERR_CLAIM_NOT_FOUND)
    )
  )
)

;; Helper function to check if caller is authorized
(define-private (is-authorized)
  ;; In a real implementation, this would check against a list of authorized users
  (is-eq tx-sender (var-get admin))
)

