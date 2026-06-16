;;; $DOOMDIR/config-editing.el -*- lexical-binding: t; -*-

;;; Company

(after! company
  (define-key! company-active-map
    "<down>" nil
    "<up>" nil
    "C-n" nil
    "C-p" nil
    "C-v" nil
    "M-v" nil
    "C-s" nil))


;;; Multiple Cursors

(map! :map mc/keymap
      "<return>" nil)


;;; Smartparens

(after! smartparens
  (sp-use-paredit-bindings)
  (setq sp-hybrid-kill-excessive-whitespace 'kill))

(map! :after smartparens
      :map smartparens-mode-map
      "M-<up>" nil
      "M-<down>" nil)


;;; Super Save

(use-package! super-save
  :config
  (add-to-list 'super-save-hook-triggers 'find-file-hook)
  (add-to-list 'super-save-triggers 'ace-window)
  (add-to-list 'super-save-triggers '+default/search-project)
  (super-save-mode t))
