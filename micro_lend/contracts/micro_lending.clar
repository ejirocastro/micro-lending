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
