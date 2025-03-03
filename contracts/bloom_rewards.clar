;; BloomChain Rewards Contract
(define-fungible-token bloom-token)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-partner (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-points (err u103))
(define-constant err-unauthorized (err u104))
(define-constant err-zero-amount (err u105))
(define-constant err-partner-exists (err u106))
(define-constant max-sustainability-score u10)

;; Data Variables
(define-data-var token-name (string-ascii 32) "Bloom Token")
(define-data-var token-symbol (string-ascii 10) "BLOM")

;; Data Maps
(define-map partners principal
  {
    name: (string-ascii 64),
    sustainability-score: uint,
    active: bool
  }
)

(define-map user-stats principal
  {
    total-points: uint,
    purchases: uint,
    redemptions: uint
  }
)

;; Partner Management
(define-public (register-partner (partner-address principal) (partner-name (string-ascii 64)) (initial-score uint))
  (let ((existing-partner (map-get? partners partner-address)))
    (if (and 
        (is-eq tx-sender contract-owner)
        (<= initial-score max-sustainability-score)
        (is-none existing-partner))
      (begin
        (map-set partners partner-address {
          name: partner-name,
          sustainability-score: initial-score,
          active: true
        })
        (ok true))
      (if (is-some existing-partner)
        err-partner-exists
        err-owner-only))))

(define-public (deactivate-partner (partner-address principal))
  (if (is-eq tx-sender contract-owner)
    (let ((partner-data (unwrap! (map-get? partners partner-address) err-not-partner)))
      (map-set partners partner-address (merge partner-data { active: false }))
      (ok true))
    err-owner-only))

;; Reward Distribution
(define-public (award-points (user principal) (amount uint) (partner principal))
  (let (
    (partner-data (unwrap! (map-get? partners partner) err-not-partner))
  )
    (if (and 
        (is-eq tx-sender partner)
        (get active partner-data)
        (> amount u0)
      )
      (let (
        (points-to-award (* amount (get sustainability-score partner-data)))
        (current-stats (default-to { total-points: u0, purchases: u0, redemptions: u0 } (map-get? user-stats user)))
      )
        (try! (ft-mint? bloom-token points-to-award user))
        (map-set user-stats user 
          (merge current-stats
            { 
              total-points: (+ points-to-award (get total-points current-stats)),
              purchases: (+ u1 (get purchases current-stats))
            }
          ))
        (ok points-to-award))
      (if (not (is-eq tx-sender partner))
        err-unauthorized
        err-not-partner))))

;; Token Redemption
(define-public (redeem-points (amount uint) (user principal))
  (if (not (is-eq tx-sender user))
    err-unauthorized
    (if (<= amount u0)
      err-zero-amount
      (let ((current-balance (ft-get-balance bloom-token user)))
        (if (>= current-balance amount)
          (begin
            (try! (ft-burn? bloom-token amount user))
            (let ((current-stats (default-to { total-points: u0, purchases: u0, redemptions: u0 } (map-get? user-stats user))))
              (map-set user-stats user 
                (merge current-stats
                  { redemptions: (+ u1 (get redemptions current-stats)) }
                ))
              (ok true)))
          err-insufficient-balance)))))

;; Read-only functions
(define-read-only (get-partner-info (partner principal))
  (ok (map-get? partners partner)))

(define-read-only (get-user-stats (user principal))
  (ok (map-get? user-stats user)))

(define-read-only (get-token-info)
  (ok {
    name: (var-get token-name),
    symbol: (var-get token-symbol)
  }))
