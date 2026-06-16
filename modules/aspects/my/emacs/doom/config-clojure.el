;;; $DOOMDIR/config-clojure.el -*- lexical-binding: t; -*-

;;; Clojure

(after! clojure-mode
  (setq cider-clojure-cli-global-options "-J-XX:-OmitStackTraceInFastThrow"
        clojure-align-forms-automatically t
        clojure-align-reader-conditionals t)
  (define-clojure-indent
    (>defn :defn)
    (conde 0)
    (fresh :defn)
    (match 1)
    (matche :defn)))


;;; Portal

;; Leverage an existing cider nrepl connection to evaluate portal.api functions
;; and map them to convenient key bindings.

;; def portal to the dev namespace to allow dereferencing via @dev/portal
(defun portal.api/open ()
  (interactive)
  (cider-nrepl-sync-request:eval
   "(do (ns dev) (def portal ((requiring-resolve 'portal.api/open) {:editor :emacs, :theme :portal.colors/solarized-dark})) (add-tap (requiring-resolve 'portal.api/submit)))"))

(defun portal.api/clear ()
  (interactive)
  (cider-nrepl-sync-request:eval "(portal.api/clear)"))

(defun portal.api/close ()
  (interactive)
  (cider-nrepl-sync-request:eval "(portal.api/close)"))

(map! :map clojure-mode-map
      "s-o" #'portal.api/open)


;;; inf-ruby

(after! inf-ruby
  (add-to-list 'inf-ruby-implementations
               `("spring" . "/Users/omarshal/co/manage/script/spring_remote rails console")))


;;; rspec-mode

(add-hook 'after-init-hook 'inf-ruby-switch-setup)
