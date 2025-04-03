;; premium-collection.clar
;; Manages small, frequent payment options

(define-data-var admin principal tx-sender)

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_FUNDS (err u101))
(define-constant ERR_POLICY_NOT_FOUND (err u102))
(define-constant ERR_ALREADY_SUBSCRIBED (err u103))
(define-constant ERR_NOT_SUBSCRIBED (err u104))

;; Subscription data structure
(define-map subscriptions
  { user: principal, policy-id: uint }
  {
    premium-amount: uint,
    last-payment: uint,
    payment-frequency: uint, ;; in days
    active: bool,
    total-paid: uint
  }
)

;; Contract reference to policy creation
(define-trait policy-trait
  (
    (get-policy (uint) (response (tuple (policy-type (string-utf8 50)) (coverage-amount uint) (premium-amount uint) (duration-days uint) (active bool) (created-by principal)) uint))
  )
)

;; Subscribe to a policy
(define-public (subscribe (policy-contract <policy-trait>) (policy-id uint))
  (let (
    (policy-data (try! (contract-call? policy-contract get-policy policy-id)))
    (premium-amount (get premium-amount policy-data))
  )
    ;; Check if already subscribed
    (asserts! (is-none (map-get? subscriptions { user: tx-sender, policy-id: policy-id })) ERR_ALREADY_SUBSCRIBED)

    ;; Make initial payment
    (try! (stx-transfer? premium-amount tx-sender (as-contract tx-sender)))

    ;; Create subscription
    (map-insert subscriptions
      { user: tx-sender, policy-id: policy-id }
      {
        premium-amount: premium-amount,
        last-payment: block-height,
        payment-frequency: u30, ;; Default to monthly (30 days)
        active: true,
        total-paid: premium-amount
      }
    )
    (ok true)
  )
)

;; Make a premium payment
(define-public (pay-premium (policy-id uint))
  (let (
    (subscription (map-get? subscriptions { user: tx-sender, policy-id: policy-id }))
  )
    (asserts! (is-some subscription) ERR_NOT_SUBSCRIBED)
    (let (
      (sub (unwrap-panic subscription))
      (premium-amount (get premium-amount sub))
    )
      ;; Transfer premium amount
      (try! (stx-transfer? premium-amount tx-sender (as-contract tx-sender)))

      ;; Update subscription
      (map-set subscriptions
        { user: tx-sender, policy-id: policy-id }
        (merge sub {
          last-payment: block-height,
          total-paid: (+ (get total-paid sub) premium-amount)
        })
      )
      (ok true)
    )
  )
)

;; Check if a subscription is active
(define-read-only (is-subscription-active (user principal) (policy-id uint))
  (let ((subscription (map-get? subscriptions { user: user, policy-id: policy-id })))
    (if (is-some subscription)
      (get active (unwrap-panic subscription))
      false
    )
  )
)

;; Get subscription details
(define-read-only (get-subscription (user principal) (policy-id uint))
  (map-get? subscriptions { user: user, policy-id: policy-id })
)

;; Cancel subscription
(define-public (cancel-subscription (policy-id uint))
  (let ((subscription (map-get? subscriptions { user: tx-sender, policy-id: policy-id })))
    (asserts! (is-some subscription) ERR_NOT_SUBSCRIBED)

    (map-set subscriptions
      { user: tx-sender, policy-id: policy-id }
      (merge (unwrap-panic subscription) { active: false })
    )
    (ok true)
  )
)

