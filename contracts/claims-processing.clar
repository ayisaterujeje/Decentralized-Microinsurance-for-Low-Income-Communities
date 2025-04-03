;; claims-processing.clar
;; Streamlines process for quick payouts

(define-data-var admin principal tx-sender)

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_CLAIM_NOT_FOUND (err u101))
(define-constant ERR_INVALID_STATUS (err u102))
(define-constant ERR_INSUFFICIENT_FUNDS (err u103))
(define-constant ERR_NOT_SUBSCRIBED (err u104))

;; Claim status
(define-constant STATUS_SUBMITTED u0)
(define-constant STATUS_UNDER_REVIEW u1)
(define-constant STATUS_APPROVED u2)
(define-constant STATUS_REJECTED u3)
(define-constant STATUS_PAID u4)

;; Claims data structure
(define-map claims
  { claim-id: uint }
  {
    claimant: principal,
    policy-id: uint,
    amount: uint,
    description: (string-utf8 500),
    status: uint,
    created-at: uint,
    updated-at: uint,
    evidence-hash: (buff 32)
  }
)

(define-data-var next-claim-id uint u1)

;; Contract references
(define-trait premium-trait
  (
    (is-subscription-active (principal uint) (response bool uint))
  )
)

(define-trait verification-trait
  (
    (get-verification-status (uint) (response uint uint))
  )
)

;; Submit a new claim
(define-public (submit-claim (premium-contract <premium-trait>) (policy-id uint) (amount uint) (description (string-utf8 500)) (evidence-hash (buff 32)))
  (let (
    (claim-id (var-get next-claim-id))
    (subscription-active (try! (contract-call? premium-contract is-subscription-active tx-sender policy-id)))
  )
    ;; Check if user has an active subscription
    (asserts! subscription-active ERR_NOT_SUBSCRIBED)

    ;; Create the claim
    (map-insert claims
      { claim-id: claim-id }
      {
        claimant: tx-sender,
        policy-id: policy-id,
        amount: amount,
        description: description,
        status: STATUS_SUBMITTED,
        created-at: block-height,
        updated-at: block-height,
        evidence-hash: evidence-hash
      }
    )

    ;; Increment claim ID
    (var-set next-claim-id (+ claim-id u1))
    (ok claim-id)
  )
)

;; Update claim status
(define-public (update-claim-status (claim-id uint) (new-status uint))
  (let ((claim (map-get? claims { claim-id: claim-id })))
    ;; Check if claim exists
    (asserts! (is-some claim) ERR_CLAIM_NOT_FOUND)
    ;; Check authorization
    (asserts! (or (is-eq tx-sender (var-get admin)) (is-authorized)) ERR_UNAUTHORIZED)
    ;; Check valid status
    (asserts! (and (>= new-status STATUS_SUBMITTED) (<= new-status STATUS_PAID)) ERR_INVALID_STATUS)

    (map-set claims
      { claim-id: claim-id }
      (merge (unwrap-panic claim) {
        status: new-status,
        updated-at: block-height
      })
    )
    (ok true)
  )
)

;; Process claim based on verification
(define-public (process-verified-claim (claim-id uint) (verification-contract <verification-trait>))
  (let (
    (claim (map-get? claims { claim-id: claim-id }))
    (verification-status (try! (contract-call? verification-contract get-verification-status claim-id)))
  )
    ;; Check if claim exists
    (asserts! (is-some claim) ERR_CLAIM_NOT_FOUND)
    ;; Check authorization
    (asserts! (or (is-eq tx-sender (var-get admin)) (is-authorized)) ERR_UNAUTHORIZED)

    (let (
      (unwrapped-claim (unwrap-panic claim))
      (new-status (if (is-eq verification-status u1) STATUS_APPROVED STATUS_REJECTED))
    )
      (map-set claims
        { claim-id: claim-id }
        (merge unwrapped-claim {
          status: new-status,
          updated-at: block-height
        })
      )
      (ok new-status)
    )
  )
)

;; Pay out an approved claim
(define-public (pay-claim (claim-id uint))
  (let (
    (claim (map-get? claims { claim-id: claim-id }))
  )
    ;; Check if claim exists
    (asserts! (is-some claim) ERR_CLAIM_NOT_FOUND)
    ;; Check authorization
    (asserts! (or (is-eq tx-sender (var-get admin)) (is-authorized)) ERR_UNAUTHORIZED)

    (let (
      (unwrapped-claim (unwrap-panic claim))
      (claimant (get claimant unwrapped-claim))
      (amount (get amount unwrapped-claim))
      (status (get status unwrapped-claim))
    )
      ;; Check if claim is approved
      (asserts! (is-eq status STATUS_APPROVED) ERR_INVALID_STATUS)

      ;; Transfer funds to claimant
      (try! (as-contract (stx-transfer? amount tx-sender claimant)))

      ;; Update claim status to paid
      (map-set claims
        { claim-id: claim-id }
        (merge unwrapped-claim {
          status: STATUS_PAID,
          updated-at: block-height
        })
      )
      (ok true)
    )
  )
)

;; Get claim details
(define-read-only (get-claim (claim-id uint))
  (map-get? claims { claim-id: claim-id })
)

;; Helper function to check if caller is authorized
(define-private (is-authorized)
  ;; In a real implementation, this would check against a list of authorized users
  (is-eq tx-sender (var-get admin))
)

