;; title: micro_lending
;; version: 1.0
;; summary: Decentralized micro-lending pool with community voting and risk-based interest
;; description: Allows lenders to deposit STX, borrowers to request loans, community voting for approval, and automated repayment/default handling

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_FUNDS (err u101))
(define-constant ERR_LOAN_NOT_FOUND (err u102))
(define-constant ERR_INVALID_LOAN_STATE (err u103))
(define-constant ERR_LOAN_OVERDUE (err u104))
(define-constant ERR_ALREADY_VOTED (err u105))
(define-constant ERR_INSUFFICIENT_STAKE (err u106))
(define-constant ERR_INVALID_PARAMETERS (err u107))
(define-constant ERR_PAUSED (err u108))

;; Data Variables
(define-data-var next-loan-id uint u1)
(define-data-var total-pool-balance uint u0)
(define-data-var total-locked-balance uint u0)
(define-data-var vote-threshold-percent uint u51) ;; 51% threshold
(define-data-var grace-period-blocks uint u144) ;; ~1 day
(define-data-var max-loan-per-borrower uint u1000000) ;; 1M microSTX
(define-data-var fee-percent uint u500) ;; 5%
(define-data-var min-lender-stake-to-vote uint u100000) ;; 100k microSTX
(define-data-var paused bool false)

;; Data Maps

;; Lender balances and voting power
(define-map lender-balances
    principal
    uint
)
(define-map lender-total-deposited
    principal
    uint
)

;; Borrower credit scores and reputation
(define-map borrower-credit-scores
    principal
    uint
)
;; 0-1000 scale
(define-map borrower-successful-repayments
    principal
    uint
)
(define-map borrower-defaults
    principal
    uint
)
(define-map borrower-active-loan-amount
    principal
    uint
)

;; Loan data structure
(define-map loans
    uint
    {
        borrower: principal,
        amount: uint,
        interest-rate: uint, ;; basis points (e.g., 1000 = 10%)
        term-end-block: uint,
        repaid-amount: uint,
        collateral-amount: uint,
        status: (string-ascii 10), ;; "requested", "approved", "active", "repaid", "defaulted"
        request-block: uint,
        risk-tier: uint, ;; 1-5 scale
    }
)

;; Voting tracking
(define-map loan-votes
    uint
    uint
)
;; loan-id -> total votes (weighted by stake)
(define-map voter-records
    {
        loan-id: uint,
        voter: principal,
    }
    bool
)

;; Events (using print for logging)
(define-private (log-event
        (event-type (string-ascii 20))
        (data (string-ascii 200))
    )
    (print {
        event: event-type,
        data: data,
        block: stacks-block-height,
    })
)

;; Interest rate calculation: base rate + risk premium + credit adjustment
;; Formula: ((risk-tier * 200) + (1000 - credit-score)) basis points
(define-read-only (calculate-interest-rate
        (credit-score uint)
        (risk-tier uint)
    )
    (let (
            (base-risk-premium (* risk-tier u200))
            (credit-adjustment (- u1000 credit-score))
        )
        (+ base-risk-premium credit-adjustment)
    )
)

;; Get borrower credit score (default 500 for new borrowers)
(define-read-only (get-credit-score (borrower principal))
    (default-to u500 (map-get? borrower-credit-scores borrower))
)

;; Check if contract is paused
(define-private (check-not-paused)
    (ok (asserts! (not (var-get paused)) ERR_PAUSED))
)

;; Admin functions
(define-public (set-vote-threshold (new-threshold uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (and (> new-threshold u0) (<= new-threshold u100))
            ERR_INVALID_PARAMETERS
        )
        (var-set vote-threshold-percent new-threshold)
        (ok true)
    )
)

(define-public (set-grace-period (new-period uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (> new-period u0) ERR_INVALID_PARAMETERS)
        (var-set grace-period-blocks new-period)
        (ok true)
    )
)

(define-public (toggle-pause)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set paused (not (var-get paused)))
        (ok true)
    )
)

;; Fast approve function for admin/oracle
(define-public (admin-approve-loan (loan-id uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (let ((loan-data (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND)))
            (asserts! (is-eq (get status loan-data) "requested")
                ERR_INVALID_LOAN_STATE
            )
            (map-set loans loan-id (merge loan-data { status: "approved" }))
            (log-event "LoanApproved" "admin-fast-approve")
            (ok true)
        )
    )
)

;; Lender deposit STX into pool
(define-public (deposit (amount uint))
    (begin
        (try! (check-not-paused))
        (asserts! (> amount u0) ERR_INVALID_PARAMETERS)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (let (
                (current-balance (default-to u0 (map-get? lender-balances tx-sender)))
                (current-total (default-to u0 (map-get? lender-total-deposited tx-sender)))
            )
            (map-set lender-balances tx-sender (+ current-balance amount))
            (map-set lender-total-deposited tx-sender (+ current-total amount))
            (var-set total-pool-balance (+ (var-get total-pool-balance) amount))
            (log-event "LenderDeposit" "deposit-successful")
            (ok true)
        )
    )
)

;; Lender withdraw available balance
(define-public (withdraw (amount uint))
    (let (
            (lender-balance (default-to u0 (map-get? lender-balances tx-sender)))
            (available-pool (- (var-get total-pool-balance) (var-get total-locked-balance)))
        )
        (asserts! (>= lender-balance amount) ERR_INSUFFICIENT_FUNDS)
        (asserts! (>= available-pool amount) ERR_INSUFFICIENT_FUNDS)
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        (map-set lender-balances tx-sender (- lender-balance amount))
        (var-set total-pool-balance (- (var-get total-pool-balance) amount))
        (log-event "LenderWithdraw" "withdraw-successful")
        (ok true)
    )
)

;; Borrower submits loan request
(define-public (request-loan
        (amount uint)
        (term-blocks uint)
        (risk-tier uint)
        (collateral-amount uint)
    )
    (begin
        (try! (check-not-paused))
        (asserts!
            (and
                (> amount u0)
                (> term-blocks u0)
                (>= risk-tier u1)
                (<= risk-tier u5)
            )
            ERR_INVALID_PARAMETERS
        )
        (let (
                (active-amount (default-to u0 (map-get? borrower-active-loan-amount tx-sender)))
                (credit-score (get-credit-score tx-sender))
                (interest-rate (calculate-interest-rate credit-score risk-tier))
                (loan-id (var-get next-loan-id))
            )
            (asserts!
                (<= (+ active-amount amount) (var-get max-loan-per-borrower))
                ERR_INVALID_PARAMETERS
            )
            (if (> collateral-amount u0)
                (try! (stx-transfer? collateral-amount tx-sender
                    (as-contract tx-sender)
                ))
                true
            )
            (map-set loans loan-id {
                borrower: tx-sender,
                amount: amount,
                interest-rate: interest-rate,
                term-end-block: (+ stacks-block-height term-blocks),
                repaid-amount: u0,
                collateral-amount: collateral-amount,
                status: "requested",
                request-block: stacks-block-height,
                risk-tier: risk-tier,
            })
            (var-set next-loan-id (+ loan-id u1))
            (log-event "LoanRequested" "new-loan-request")
            (ok loan-id)
        )
    )
)

;; Lenders vote on loan approval
(define-public (vote-on-loan (loan-id uint))
    (let (
            (loan-data (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND))
            (voter-stake (default-to u0 (map-get? lender-balances tx-sender)))
            (current-votes (default-to u0 (map-get? loan-votes loan-id)))
        )
        (asserts! (is-eq (get status loan-data) "requested")
            ERR_INVALID_LOAN_STATE
        )
        (asserts! (>= voter-stake (var-get min-lender-stake-to-vote))
            ERR_INSUFFICIENT_STAKE
        )
        (asserts!
            (is-none (map-get? voter-records {
                loan-id: loan-id,
                voter: tx-sender,
            }))
            ERR_ALREADY_VOTED
        )
        (map-set voter-records {
            loan-id: loan-id,
            voter: tx-sender,
        }
            true
        )
        (let (
                (new-votes (+ current-votes voter-stake))
                (threshold-votes (* (var-get total-pool-balance) (var-get vote-threshold-percent)
                    (/ u1 u100)
                ))
            )
            (map-set loan-votes loan-id new-votes)
            (if (>= new-votes threshold-votes)
                (begin
                    (map-set loans loan-id
                        (merge loan-data { status: "approved" })
                    )
                    (log-event "LoanApproved" "community-vote-approved")
                    true
                )
                true
            )
            (ok true)
        )
    )
)

;; Disburse approved loan to borrower
(define-public (disburse-loan (loan-id uint))
    (let ((loan-data (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND)))
        (asserts! (is-eq (get status loan-data) "approved")
            ERR_INVALID_LOAN_STATE
        )
        (asserts!
            (>= (- (var-get total-pool-balance) (var-get total-locked-balance))
                (get amount loan-data)
            )
            ERR_INSUFFICIENT_FUNDS
        )
        (try! (as-contract (stx-transfer? (get amount loan-data) tx-sender (get borrower loan-data))))
        (map-set loans loan-id (merge loan-data { status: "active" }))
        (var-set total-locked-balance
            (+ (var-get total-locked-balance) (get amount loan-data))
        )
        (let ((current-active (default-to u0
                (map-get? borrower-active-loan-amount (get borrower loan-data))
            )))
            (map-set borrower-active-loan-amount (get borrower loan-data)
                (+ current-active (get amount loan-data))
            )
        )
        (log-event "LoanDisbursed" "funds-sent-to-borrower")
        (ok true)
    )
)

;; Borrower repays loan (partial or full)
(define-public (repay-loan
        (loan-id uint)
        (repay-amount uint)
    )
    (let ((loan-data (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get borrower loan-data)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status loan-data) "active") ERR_INVALID_LOAN_STATE)
        (asserts! (> repay-amount u0) ERR_INVALID_PARAMETERS)
        (try! (stx-transfer? repay-amount tx-sender (as-contract tx-sender)))
        (let (
                (new-repaid-amount (+ (get repaid-amount loan-data) repay-amount))
                (total-owed (+ (get amount loan-data)
                    (/ (* (get amount loan-data) (get interest-rate loan-data))
                        u10000
                    )))
                (protocol-fee (/ (* repay-amount (var-get fee-percent)) u10000))
            )
            (map-set loans loan-id
                (merge loan-data { repaid-amount: new-repaid-amount })
            )
            (var-set total-pool-balance
                (+ (var-get total-pool-balance) (- repay-amount protocol-fee))
            )
            (if (>= new-repaid-amount total-owed)
                (begin
                    (map-set loans loan-id (merge loan-data { status: "repaid" }))
                    (var-set total-locked-balance
                        (- (var-get total-locked-balance) (get amount loan-data))
                    )
                    (let ((current-active (default-to u0
                            (map-get? borrower-active-loan-amount tx-sender)
                        )))
                        (map-set borrower-active-loan-amount tx-sender
                            (- current-active (get amount loan-data))
                        )
                    )
                    (if (> (get collateral-amount loan-data) u0)
                        (try! (as-contract (stx-transfer? (get collateral-amount loan-data)
                            tx-sender (get borrower loan-data)
                        )))
                        true
                    )
                    (let (
                            (current-successful (default-to u0
                                (map-get? borrower-successful-repayments
                                    tx-sender
                                )))
                            (current-score (get-credit-score tx-sender))
                        )
                        (map-set borrower-successful-repayments tx-sender
                            (+ current-successful u1)
                        )
                        (map-set borrower-credit-scores tx-sender
                            (if (<= (+ current-score u10) u1000)
                                (+ current-score u10)
                                u1000
                            ))
                    )
                    (log-event "LoanRepaid" "loan-fully-repaid")
                    (log-event "ReputationUpdated" "credit-score-increased")
                )
                (log-event "RepaymentReceived" "partial-repayment")
            )
            (log-event "ProtocolFeeCollected" "fee-deducted")
            (ok true)
        )
    )
)

;; Handle loan default (callable by lenders or after grace period)
(define-public (handle-default (loan-id uint))
    (let (
            (loan-data (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND))
            (caller-stake (default-to u0 (map-get? lender-balances tx-sender)))
        )
        (asserts! (is-eq (get status loan-data) "active") ERR_INVALID_LOAN_STATE)
        (asserts!
            (> (+ (get term-end-block loan-data) (var-get grace-period-blocks))
                stacks-block-height
            )
            ERR_LOAN_OVERDUE
        )
        (asserts! (or (> caller-stake u0) (is-eq tx-sender CONTRACT_OWNER))
            ERR_UNAUTHORIZED
        )
        (map-set loans loan-id (merge loan-data { status: "defaulted" }))
        (var-set total-locked-balance
            (- (var-get total-locked-balance) (get amount loan-data))
        )
        (let ((current-active (default-to u0
                (map-get? borrower-active-loan-amount (get borrower loan-data))
            )))
            (map-set borrower-active-loan-amount (get borrower loan-data)
                (- current-active (get amount loan-data))
            )
        )
        (if (> (get collateral-amount loan-data) u0)
            (var-set total-pool-balance
                (+ (var-get total-pool-balance) (get collateral-amount loan-data))
            )
            true
        )
        (let (
                (current-defaults (default-to u0
                    (map-get? borrower-defaults (get borrower loan-data))
                ))
                (current-score (get-credit-score (get borrower loan-data)))
            )
            (map-set borrower-defaults (get borrower loan-data)
                (+ current-defaults u1)
            )
            (map-set borrower-credit-scores (get borrower loan-data)
                (if (>= current-score u50)
                    (- current-score u50)
                    u0
                ))
        )
        (log-event "LoanDefaulted" "default-processed")
        (log-event "ReputationUpdated" "credit-score-decreased")
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-loan-details (loan-id uint))
    (map-get? loans loan-id)
)

(define-read-only (get-lender-balance (lender principal))
    (default-to u0 (map-get? lender-balances lender))
)

(define-read-only (get-pool-stats)
    {
        total-pool-balance: (var-get total-pool-balance),
        total-locked-balance: (var-get total-locked-balance),
        available-liquidity: (- (var-get total-pool-balance) (var-get total-locked-balance)),
        next-loan-id: (var-get next-loan-id),
    }
)

(define-read-only (get-borrower-reputation (borrower principal))
    {
        credit-score: (get-credit-score borrower),
        successful-repayments: (default-to u0 (map-get? borrower-successful-repayments borrower)),
        defaults: (default-to u0 (map-get? borrower-defaults borrower)),
        active-loan-amount: (default-to u0 (map-get? borrower-active-loan-amount borrower)),
    }
)

(define-read-only (get-loan-votes (loan-id uint))
    (default-to u0 (map-get? loan-votes loan-id))
)

(define-read-only (get-governance-params)
    {
        vote-threshold-percent: (var-get vote-threshold-percent),
        grace-period-blocks: (var-get grace-period-blocks),
        max-loan-per-borrower: (var-get max-loan-per-borrower),
        fee-percent: (var-get fee-percent),
        min-lender-stake-to-vote: (var-get min-lender-stake-to-vote),
        paused: (var-get paused),
    }
)
