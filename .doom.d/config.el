;;; ~/.doom.d/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here

(defun my-yank ()
    (interactive)
    (if (nth 3 (syntax-ppss)) ;; Checks if inside a string
        (insert-for-yank (replace-regexp-in-string "[\\\"]"
                                                   "\\\\\\&"
                                                   (current-kill 0)
                                                   t))
      (call-interactively 'yank)))

(defun rebl-inspect-last-sexp ()
    (interactive)
    (cider-interactive-eval
     (format "(require 'cognitect.rebl)
              (cognitect.rebl/inspect %s)"
             (cider-last-sexp))))

(setq-default fill-column 120)
(setq doom-font (font-spec :family "Source Code Pro" :size 12))

(after! avy
  (setq avy-keys '(97 111 101 117 104 116 110 115))
  (setq avy-all-windows t))
(map! "C-'" #'avy-goto-char-2
      "C-:" #'avy-goto-char
      "M-g e" #'avy-goto-word-0
      "M-g w" #'avy-goto-word-1
      [remap goto-line] #'avy-goto-line)
(after! ace-window
  (setq aw-keys '(97 111 101 117 104 116 110 115)))
(after! cider
  (setq cider-print-fn 'puget))
(map! "C-M-z" #'cider-format-defun
      :map doom-leader-file-map
      "c" #'cider-scratch)
(after! clojure-mode
  (require 'flycheck-clj-kondo)
  (define-clojure-indent
    (>defn :defn)
    (>defn- :defn)
    (>fdef :defn)
    (defcomponent '(1 :form :defn))
    (defmutation '(:defn :defn))
    (defprotocol+ '(1 (:defn)))
    (defrecord+ '(2 nil nil (:defn)))
    (defui '(1 :form :defn))
    (fnk :defn)
    (reporting :defn)
    (ui '(0 :form :defn))))
(after! company
  (define-key! company-active-map
    "<down>" nil
    "<up>" nil
    "C-n" nil
    "C-p" nil
    "C-v" nil
    "M-v" nil
    "C-s" nil))
(map! "C-c w s" #'copy-as-format-slack
      "C-c w g" #'copy-as-format-github)
(map! "C-+" #'er/expand-region
      "C-0" #'er/mark-defun)
(after! browse-at-remote
  (setq browse-at-remote-prefer-symbolic nil))
(map! "C-$" #'+nav-flash/blink-cursor)
(after! projectile
  (setq projectile-globally-ignored-directories '(".idea"
                                                  ".ensime_cache"
                                                  ".eunit"
                                                  ".git"
                                                  ".hg"
                                                  ".fslckout"
                                                  "_FOSSIL_"
                                                  ".bzr"
                                                  "_darcs"
                                                  ".tox"
                                                  ".svn"
                                                  ".stack-work"
                                                  "jupyter")
        projectile-globally-ignored-file-suffixes '(".autogenerated"
                                                    ".min.js"
                                                    ".svg")))
(after! smartparens
  (sp-use-paredit-bindings)
  (smartparens-global-strict-mode t)
  (setq sp-hybrid-kill-excessive-whitespace 'kill))
(map! "M-{" (lambda (_) (interactive "P") (sp-wrap-with-pair "{"))
      "M-[" (lambda (_) (interactive "P") (sp-wrap-with-pair "[")))
(map! [remap isearch-forward] #'swiper
      [remap isearch-backward] #'swiper-backward)

(use-package! crux
  :bind (("C-<backspace>" . crux-kill-line-backwards)
         ("C-M-z" . crux-indent-defun)
         ("C-S-<backspace>" . crux-kill-whole-line)
         ("C-S-<return>" . crux-smart-open-line-above)
         ("C-a" . crux-move-beginning-of-line)
         ("C-c D" . crux-delete-file-and-buffer)
         ("C-c I" . crux-find-user-init-file)
         ("C-c M-d" . crux-duplicate-and-comment-current-line-or-region)
         ("C-c S" . crux-find-shell-init-file)
         ("C-c TAB" . crux-indent-rigidly-and-copy-to-clipboard)
         ("C-c d" . crux-duplicate-current-line-or-region)
         ("C-c e" . crux-eval-and-replace)
         ("C-c f" . crux-recentf-find-file)
         ("C-c i" . crux-ispell-word-then-abbrev)
         ("C-c k" . crux-kill-other-buffers)
         ("C-c n" . crux-cleanup-buffer-or-region)
         ("C-c o" . crux-open-with)
         ("C-c r" . crux-rename-file-and-buffer)
         ("C-c t" . crux-visit-term-buffer)
         ("C-c u" . crux-view-url)
         ("C-x 4 t" . crux-transpose-windows)
         ("S-<return>" . crux-smart-open-line)
         ("s-j" . crux-top-join-line)
         ([replace kill-line] . crux-smart-kill-line)))
(use-package! highlight-symbol
  :hook (prog-mode . highlight-symbol-mode))
(use-package! html-to-hiccup)
(use-package! super-save
  :config
  (add-to-list 'super-save-triggers 'ace-window)
  (add-to-list 'super-save-triggers '+default/search-project)
  (super-save-mode t))

(global-whitespace-mode t)
(setq whitespace-style '(face lines-tail tab-mark trailing))

(map! "C-e" #'end-of-line
      "C-M-H" #'hs-hide-block
      "C-M-S" #'hs-show-block
      "C-M-s-H" #'hs-hide-all
      "C-M-s-S" #'hs-show-all
      "C-Y" #'my-yank
      "M-s-i" #'rebl-inspect-last-sexp
      "s-+" #'doom/increase-font-size
      "s-0" #'doom-big-font-mode
      "s-_" #'doom/reset-font-size
      (:map mc/keymap
        "<return>" nil))