;; policy-creation.clar
;; Defines affordable coverage for specific risks

(define-data-var admin principal tx-sender)

;; Policy types
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_POLICY_TYPE (err u101))
(define-constant ERR_POLICY_EXISTS (err u102))
(define-constant ERR_POLICY_NOT_FOUND (err u103))

;; Policy data structure
(define-map policies
  { policy-id: uint }
  {
    policy-type: (string-utf8 50),
    coverage-amount: uint,
    premium-amount: uint,
    duration-days: uint,
    active: bool,
    created-by: principal
  }
)

(define-data-var next-policy-id uint u1)

;; Create a new policy type
(define-public (create-policy-type (policy-type (string-utf8 50)) (coverage-amount uint) (premium-amount uint) (duration-days uint))
  (let ((policy-id (var-get next-policy-id)))
    (asserts! (or (is-eq tx-sender (var-get admin)) (is-authorized)) ERR_UNAUTHORIZED)
    (map-insert policies
      { policy-id: policy-id }
      {
        policy-type: policy-type,
        coverage-amount: coverage-amount,
        premium-amount: premium-amount,
        duration-days: duration-days,
        active: true,
        created-by: tx-sender
      }
    )
    (var-set next-policy-id (+ policy-id u1))
    (ok policy-id)
  )
)

;; Get policy details
(define-read-only (get-policy (policy-id uint))
  (map-get? policies { policy-id: policy-id })
)

;; Update policy status (active/inactive)
(define-public (update-policy-status (policy-id uint) (active bool))
  (let ((policy (map-get? policies { policy-id: policy-id })))
    (asserts! (is-some policy) ERR_POLICY_NOT_FOUND)
    (asserts! (or (is-eq tx-sender (var-get admin)) (is-authorized)) ERR_UNAUTHORIZED)

    (map-set policies
      { policy-id: policy-id }
      (merge (unwrap-panic policy) { active: active })
    )
    (ok true)
  )
)

;; Helper function to check if caller is authorized
(define-private (is-authorized)
  ;; In a real implementation, this would check against a list of authorized users
  ;; For simplicity, we're just checking if it's the admin
  (is-eq tx-sender (var-get admin))
)

