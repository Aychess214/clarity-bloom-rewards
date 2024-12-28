;; BloomChain Rewards Contract
(define-fungible-token bloom-token)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-partner (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-points (err u103))

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
  (if (is-eq tx-sender contract-owner)
    (begin
      (map-set partners partner-address {
        name: partner-name,
        sustainability-score: initial-score,
        active: true
      })
      (ok true)
    )
    err-owner-only
  )
)

;; Reward Distribution
(define-public (award-points (user principal) (amount uint) (partner principal))
  (let (
    (partner-data (unwrap! (map-get? partners partner) err-not-partner))
    (points-to-award (* amount (get sustainability-score partner-data)))
  )
    (if (get active partner-data)
      (begin
        (try! (ft-mint? bloom-token points-to-award user))
        (map-set user-stats user 
          (merge (default-to 
            { total-points: u0, purchases: u0, redemptions: u0 } 
            (map-get? user-stats user))
            { 
              total-points: (+ points-to-award (default-to u0 (get total-points (map-get? user-stats user)))),
              purchases: (+ u1 (default-to u0 (get purchases (map-get? user-stats user))))
            }
          ))
        (ok points-to-award)
      )
      err-not-partner
    )
  )
)

;; Token Redemption
(define-public (redeem-points (amount uint) (user principal))
  (let (
    (current-balance (ft-get-balance bloom-token user))
  )
    (if (>= current-balance amount)
      (begin
        (try! (ft-burn? bloom-token amount user))
        (map-set user-stats user 
          (merge (default-to 
            { total-points: u0, purchases: u0, redemptions: u0 } 
            (map-get? user-stats user))
            { redemptions: (+ u1 (default-to u0 (get redemptions (map-get? user-stats user)))) }
          ))
        (ok true)
      )
      err-insufficient-balance
    )
  )
)

;; Read-only functions
(define-read-only (get-partner-info (partner principal))
  (ok (map-get? partners partner))
)

(define-read-only (get-user-stats (user principal))
  (ok (map-get? user-stats user))
)

(define-read-only (get-token-info)
  (ok {
    name: (var-get token-name),
    symbol: (var-get token-symbol)
  })
)