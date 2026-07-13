;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; https://github.com/doomemacs/doomemacs/issues/8541#issuecomment-3421113668
(let ((lfile (concat doom-local-dir "straight/repos/transient/lisp/transient.el")))
  (if (file-exists-p lfile)
      (load lfile)))


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets.
(setq user-full-name "Oscar Marshall"
      user-mail-address "oscar.marshall@meraki.net")

;; Doom exposes five (optional) variables for controlling fonts in Doom. Here
;; are the three important ones:
;;
;; + `doom-font'
;; + `doom-variable-pitch-font'
;; + `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;;
;; They all accept either a font-spec, font string ("Input Mono-12"), or xlfd
;; font string. You generally only need these two:
(setq doom-font "Maple Mono NF-12" ;(font-spec :family "Maple Mono NF" :size 12)
      doom-variable-pitch-font (font-spec :family "Inter" :size 13))

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'catppuccin)
(add-hook 'ns-system-appearance-change-functions
          (lambda (appearance)
            "Load theme, taking current system APPEARANCE into consideration."
            ;;(mapc #'disable-theme custom-enabled-themes)
            (setq catppuccin-flavor (pcase appearance
                                      ('light 'latte)
                                      ('dark 'mocha)))
            (catppuccin-reload)))

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)


(load! "config-ui")
(load! "config-navigation")
(load! "config-editing")
(load! "config-org")
(load! "config-clojure")
(load! "config-web")
(load! "config-git")
