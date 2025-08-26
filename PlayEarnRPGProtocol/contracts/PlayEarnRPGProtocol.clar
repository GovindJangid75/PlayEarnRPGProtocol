;; PlayEarn RPG Protocol
;; A blockchain-based RPG system with character progression and tradeable assets
;; Define the in-game asset token (tradeable items/equipment)
(define-non-fungible-token game-asset uint)
;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-asset-owner (err u101))
(define-constant err-character-not-found (err u102))
(define-constant err-invalid-level (err u103))
(define-constant err-asset-not-found (err u104))
(define-constant err-insufficient-experience (err u105))
;; Character data structure
(define-map characters
  principal
  {
    level: uint,
    experience: uint,
    health: uint,
    attack: uint,
    defense: uint,
    created-at: uint,
  }
)
;; Game assets metadata
(define-map asset-metadata
  uint
  {
    name: (string-ascii 50),
    asset-type: (string-ascii 20),
    rarity: (string-ascii 10),
    attack-boost: uint,
    defense-boost: uint,
    owner: principal,
  }
)
;; Asset ID counter
(define-data-var next-asset-id uint u1)
;; Experience required per level (simple progression)
(define-constant base-exp-required u100)
;; Function 1: Create/Level Up Character
;; Creates a new character or levels up existing one based on experience gained
(define-public (level-up-character (exp-gained uint))
  (let (
      (current-character (map-get? characters tx-sender))
      (current-block stacks-block-height)
  )
    (match current-character
      ;; Character exists - level them up
      existing-char
      (let (
          (new-exp (+ (get experience existing-char) exp-gained))
          (current-level (get level existing-char))
          (exp-for-next-level (* (+ current-level u1) base-exp-required))
        )
        (if (>= new-exp exp-for-next-level)
          ;; Level up!
          (let (
              (new-level (+ current-level u1))
              (health-boost (* new-level u20))
              (attack-boost (* new-level u5))
              (defense-boost (* new-level u3))
            )
            (begin
              (map-set characters tx-sender {
                level: new-level,
                experience: new-exp,
                health: (+ (get health existing-char) health-boost),
                attack: (+ (get attack existing-char) attack-boost),
                defense: (+ (get defense existing-char) defense-boost),
                created-at: (get created-at existing-char),
              })
              (print {
                event: "level-up",
                player: tx-sender,
                new-level: new-level,
              })
              (ok {
                leveled-up: true,
                new-level: new-level,
                total-exp: new-exp,
              })
            )
          )
          ;; Just add experience, no level up
          (begin
            (map-set characters tx-sender
              (merge existing-char { experience: new-exp })
            )
            (ok {
              leveled-up: false,
              new-level: current-level,
              total-exp: new-exp,
            })
          )
        )
      )
      ;; Character doesn't exist - create new one
      (begin
        (map-set characters tx-sender {
          level: u1,
          experience: exp-gained,
          health: u100,
          attack: u10,
          defense: u5,
          created-at: current-block,
        })
        (print {
          event: "character-created",
          player: tx-sender,
        })
        (ok {
          leveled-up: false,
          new-level: u1,
          total-exp: exp-gained,
        })
      )
    )
  )
)
;; Function 2: Mint and Trade Game Assets
;; Mints tradeable in-game assets (equipment, items) and handles transfers
(define-public (mint-and-trade-asset
    (asset-name (string-ascii 50))
    (asset-type (string-ascii 20))
    (rarity (string-ascii 10))
    (attack-boost uint)
    (defense-boost uint)
    (recipient (optional principal))
  )
  (let (
      (asset-id (var-get next-asset-id))
      (final-recipient (default-to tx-sender recipient))
    )
    ;; Only allow minting if sender has a character
    (asserts! (is-some (map-get? characters tx-sender)) err-character-not-found)
    ;; Mint the NFT asset
    (try! (nft-mint? game-asset asset-id final-recipient))
    ;; Set asset metadata
    (map-set asset-metadata asset-id {
      name: asset-name,
      asset-type: asset-type,
      rarity: rarity,
      attack-boost: attack-boost,
      defense-boost: defense-boost,
      owner: final-recipient,
    })
    ;; Increment asset ID counter
    (var-set next-asset-id (+ asset-id u1))
    ;; If recipient is different from sender, it's a trade/transfer
    (if (not (is-eq tx-sender final-recipient))
      (print {
        event: "asset-traded",
        asset-id: asset-id,
        from: tx-sender,
        to: final-recipient,
      })
      (print {
        event: "asset-minted",
        asset-id: asset-id,
        to: final-recipient,
        from: tx-sender,
      })
    )
    (ok {
      asset-id: asset-id,
      name: asset-name,
      owner: final-recipient,
    })
  )
)
;; Read-only functions for game state
;; Get character stats
(define-read-only (get-character (player principal))
  (map-get? characters player)
)
;; Get asset metadata
(define-read-only (get-asset-info (asset-id uint))
  (map-get? asset-metadata asset-id)
)
;; Get asset owner
(define-read-only (get-asset-owner (asset-id uint))
  (nft-get-owner? game-asset asset-id)
)
;; Calculate experience needed for next level
(define-read-only (get-exp-for-next-level (player principal))
  (match (map-get? characters player)
    character (ok (* (+ (get level character) u1) base-exp-required))
    (err err-character-not-found)
  )
)
;; Get total assets minted
(define-read-only (get-total-assets)
  (ok (- (var-get next-asset-id) u1))
)