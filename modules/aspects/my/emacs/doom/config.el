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
(setq doom-font "Fira Code-12" ;(font-spec :family "Fira Code" :size 12)
      doom-variable-pitch-font (font-spec :family "Helvetica Neue" :size 13))

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


;; Here are some additional functions/macros that could help you configure Doom:
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.


;;; Emacs

(setq-default fill-column 120)
(add-hook 'doom-first-buffer-hook #'global-display-fill-column-indicator-mode)
(add-hook 'prog-mode-hook (lambda ()
                            (setq prettify-symbols-alist nil
                                  subword-mode 1)))

;;; Doom

(map! "s-+" #'doom/increase-font-size
      "s-0" #'doom-big-font-mode
      "s-_" #'doom/reset-font-size)


;;; Avy

(after! avy
  (setq avy-keys '(97 111 101 117 104 116 110 115)
        avy-all-windows t))

(map! "C-'" #'avy-goto-char-2
      "C-:" #'avy-goto-char
      "M-g e" #'avy-goto-word-0
      "M-g w" #'avy-goto-word-1
      [remap goto-line] #'avy-goto-line)


;;; Ace Window

(after! ace-window
  (setq aw-keys '(97 111 101 117 104 116 110 115)))


;;; Browse at Remote

(after! browse-at-remote
  (defun browse-at-remote--format-commit-url-as-gerrit (_repo-url commithash)
    "Commit URL formatted for gerrit"
    (format "https://gerrit.ikarem.io/plugins/gitiles/manage/+/%s" commithash))

  (defun browse-at-remote--format-region-url-as-gerrit (_repo-url location filename &optional linestart _lineend)
    "URL formatted for gerrit."
    (if linestart (format "https://gerrit.ikarem.io/plugins/gitiles/manage/+/%s/%s#%d" location filename linestart)
      (format "https://gerrit.ikarem.io/plugins/gitiles/manage/+/%s/%s" location filename)))

  (setq browse-at-remote-prefer-symbolic nil)
  (add-to-list 'browse-at-remote-remote-type-regexps '(:host "^gerrit\\.ikarem\\.io$" :type "gerrit")))

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


;;; Deft

(setq deft-directory org-directory
      deft-recursive t)


;;; Expand Region

(map! "C-+" #'er/expand-region
      "C-0" #'er/mark-defun)


;;; Gerrit

(after! gerrit
  (setq
   gerrit-host "gerrit.ikarem.io"

   gerrit-dashboard-query-alist
   '(("Has draft comments" . "has:draft")
     ("Your turn" . "attention:self")
     ("Work in progress" . "is:open owner:self is:wip")
     ("Outgoing reviews" . "is:open owner:self -is:wip")
     ("Incoming reviews" . "is:open -owner:self -is:wip reviewer:self")
     ("CCed on" . "is:open cc:self")
     ("Recently closed" . "is:closed (-is:wip OR owner:self) (owner:self OR reviewer:self OR cc:self) limit:15")))
  (add-hook 'magit-status-sections-hook #'gerrit-magit-insert-status t))


;;; Hide Show

(map! "C-M-H" #'hs-hide-block
      "C-M-S" #'hs-show-block
      "C-M-s-H" #'hs-hide-all
      "C-M-s-S" #'hs-show-all)


;;; inf-ruby

(after! inf-ruby
  (add-to-list 'inf-ruby-implementations
               `("spring" . "/Users/omarshal/co/manage/script/spring_remote rails console")))


;;; JS

(after! js2-mode
  (setq js-chain-indent nil
        js-indent-align-list-continuation nil
        js-indent-first-init nil
        js-indent-level 2))


;;; Ligatutures

(after! ligature
  ;; Enable the "www" ligature in every possible major mode
  (ligature-set-ligatures 't '("www"))
  ;; Enable traditional ligature support in eww-mode, if the
  ;; `variable-pitch' face supports it
  (ligature-set-ligatures 'eww-mode '("ff" "fi" "ffi"))
  ;; Enable all Cascadia and Fira Code ligatures in programming modes
  (ligature-set-ligatures 'prog-mode
                          '(;; == === ==== => =| =>>=>=|=>==>> ==< =/=//=// =~
                            ;; =:= =!=
                            ("=" (rx (+ (or ">" "<" "|" "/" "~" ":" "!" "="))))
                            ;; ;; ;;;
                            (";" (rx (+ ";")))
                            ;; && &&&
                            ("&" (rx (+ "&")))
                            ;; !! !!! !. !: !!. != !== !~
                            ("!" (rx (+ (or "=" "!" "\." ":" "~"))))
                            ;; ?? ??? ?:  ?=  ?.
                            ("?" (rx (or ":" "=" "\." (+ "?"))))
                            ;; %% %%%
                            ("%" (rx (+ "%")))
                            ;; |> ||> |||> ||||> |] |} || ||| |-> ||-||
                            ;; |->>-||-<<-| |- |== ||=||
                            ;; |==>>==<<==<=>==//==/=!==:===>
                            ("|" (rx (+ (or ">" "<" "|" "/" ":" "!" "}" "\]"
                                            "-" "=" ))))
                            ;; \\ \\\ \/
                            ("\\" (rx (or "/" (+ "\\"))))
                            ;; ++ +++ ++++ +>
                            ("+" (rx (or ">" (+ "+"))))
                            ;; :: ::: :::: :> :< := :// ::=
                            (":" (rx (or ">" "<" "=" "//" ":=" (+ ":"))))
                            ;; // /// //// /\ /* /> /===:===!=//===>>==>==/
                            ("/" (rx (+ (or ">"  "<" "|" "/" "\\" "\*" ":" "!"
                                            "="))))
                            ;; .. ... .... .= .- .? ..= ..<
                            ("\." (rx (or "=" "-" "\?" "\.=" "\.<" (+ "\."))))
                            ;; -- --- ---- -~ -> ->> -| -|->-->>->--<<-|
                            ("-" (rx (+ (or ">" "<" "|" "~" "-"))))
                            ;; *> */ *)  ** *** ****
                            ("*" (rx (or ">" "/" ")" (+ "*"))))
                            ;; www wwww
                            ("w" (rx (+ "w")))
                            ;; <> <!-- <|> <: <~ <~> <~~ <+ <* <$ </  <+> <*>
                            ;; <$> </> <|  <||  <||| <|||| <- <-| <-<<-|-> <->>
                            ;; <<-> <= <=> <<==<<==>=|=>==/==//=!==:=>
                            ;; << <<< <<<<
                            ("<" (rx (+ (or "\+" "\*" "\$" "<" ">" ":" "~"  "!"
                                            "-"  "/" "|" "="))))
                            ;; >: >- >>- >--|-> >>-|-> >= >== >>== >=|=:=>>
                            ;; >> >>> >>>>
                            (">" (rx (+ (or ">" "<" "|" "/" ":" "=" "-"))))
                            ;; #: #= #! #( #? #[ #{ #_ #_( ## ### #####
                            ("#" (rx (or ":" "=" "!" "(" "\?" "\[" "{" "_(" "_"
                                         (+ "#"))))
                            ;; ~~ ~~~ ~=  ~-  ~@ ~> ~~>
                            ("~" (rx (or ">" "=" "-" "@" "~>" (+ "~"))))
                            ;; __ ___ ____ _|_ __|____|_
                            ("_" (rx (+ (or "_" "|"))))
                            ;; Fira code: 0xFF 0x12
                            ("0" (rx (and "x" (+ (in "A-F" "a-f" "0-9")))))
                            ;; Fira code:
                            "Fl"  "Tl"  "fi"  "fj"  "fl"  "ft"
                            ;; The few not covered by the regexps.
                            "{|"  "[|"  "]#"  "(*"  "}#"  "$>"  "^=")))


;;; Multiple Cursors

(map! :map mc/keymap
      "<return>" nil)


;;; Org

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/Google Drive/org")

(after! org
  (setq org-agenda-custom-commands
        '(("@" . "Contexts")
          ("@w" . "Work")
          ("@wt" "Todo" tags-todo "ALLTAGS={@work}-SCHEDULED>=\"<today>\"/TODO|STRT"
           ((org-agenda-files (list (concat (file-name-as-directory org-directory)
                                            "gtd.org")))))
          ("@ww" "Waiting For" tags-todo "ALLTAGS={@work}/WAIT")
          ("@wp" "Projects" tags-todo "ALLTAGS={@work}/PROJ")
          ("@h" . "Home")
          ("@ht" "Todo" tags-todo "ALLTAGS={@home}-SCHEDULED>=\"<today>\"/TODO|STRT"
           ((org-agenda-files (list (concat (file-name-as-directory org-directory)
                                            "gtd.org")))))
          ("@hw" "Waiting For" tags-todo "ALLTAGS={@home}/WAIT")
          ("@hp" "Projects" tags-todo "ALLTAGS={@home}/PROJ"))
        org-capture-templates
        '(("t" "Todo" entry
           (file "inbox.org")
           "* TODO %?\n%i\n%a" :prepend t)
          ("j" "Jira" entry
           (file "gtd.org")
           "* PROJ %^{Ticket}: %^{Title} :@work:\n:PROPERTIES:\n:URL: [[https://jira.ikarem.io/browse/%\\1]]\n:END:%?\n\n** TODO Implement %\\1\n** HOLD Address CRs for %\\1\n** HOLD Merge %\\1 to dev\n** HOLD Merge %\\1 to prod"))
        org-refile-targets
        '((nil :maxlevel . 3)
          (org-agenda-files :maxlevel . 3))))


;;; Org-jira

;; (use-package! org-jira
;;   :custom
;;   (jiralib-url "https://jira.ikarem.io")
;;   (org-jira-working-directory org-directory))


;;; Org-roam

;; (setq org-roam-capture-templates
;;       '(("d" "default" plain
;;          #'org-roam--capture-get-point
;;          "%?"
;;          :file-name "${slug}"
;;          :head "#+TITLE: ${title}\n"
;;          :unnarrowed t))
;;       org-roam-dailies-capture-templates
;;       '(("d" "default" entry
;;          #'org-roam-capture--get-point
;;          "* %T %?"
;;          :file-name "%<%Y-%m-%d>"
;;          :head "#+TITLE: %<%Y-%m-%d>\n\n"))
;;       org-roam-directory org-directory)


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

;; Example key mappings for doom emacs
(map! :map clojure-mode-map
      ;; cmd  + o
      "s-o" #'portal.api/open)

;; Overwrite existing scss-stylelint checker to not use --syntax
(flycheck-define-checker scss-stylelint
  "A SCSS syntax and style checker using stylelint.
See URL `http://stylelint.io/'."
  :command ("stylelint"
            (eval flycheck-stylelint-args)
            ;; "--syntax" "scss"
            "--config-basedir" "/Users/oscar.marshall/.config/yarn/global"
            (option-flag "--quiet" flycheck-stylelint-quiet)
            (config-file "--config" flycheck-stylelintrc))
  :standard-input t
  :error-parser flycheck-parse-stylelint
  :predicate flycheck-buffer-nonempty-p
  :modes (scss-mode))

;; Overwrite existing ruby-rubocop checker to not use --stdin
(flycheck-define-command-checker 'ruby-rubocop
  "A Ruby syntax and style checker using the RuboCop tool.

You need at least RuboCop 0.34 for this syntax checker.

See URL `https://rubocop.org/'."
  ;; ruby-standard is defined based on this checker
  :command '("rubocop"
             "--display-cop-names"
             "--force-exclusion"
             "--format" "emacs"
             ;; Explicitly disable caching to prevent Rubocop 0.35.1 and earlier
             ;; from caching standard input.  Later versions of Rubocop
             ;; automatically disable caching with --stdin, see
             ;; https://github.com/flycheck/flycheck/issues/844 and
             ;; https://github.com/bbatsov/rubocop/issues/2576
             "--cache" "false"
             (config-file "--config" flycheck-rubocoprc)
             (option-flag "--lint" flycheck-rubocop-lint-only)
             ;; Rubocop takes the original file name as argument when reading
             ;; from standard input
             source-original)
  :working-directory #'flycheck-ruby--find-project-root
  :error-patterns flycheck-ruby-rubocop-error-patterns
  :modes '(enh-ruby-mode ruby-mode ruby-ts-mode)
  :next-checkers '((warning . ruby-reek)
                   (warning . ruby-rubylint)))


;;; rspec-mode
(add-hook 'after-init-hook 'inf-ruby-switch-setup)


;;; Smartparens

(after! smartparens
  (sp-use-paredit-bindings)
  (setq sp-hybrid-kill-excessive-whitespace 'kill))

(map! :after smartparens
      :map smartparens-mode-map
      "M-<up>" nil
      "M-<down>" nil)


;;; Swiper

;; (map! [remap isearch-forward] #'swiper
;;       [remap isearch-backward] #'swiper-backward)


;;; Super Save

(use-package! super-save
  :config
  (add-to-list 'super-save-hook-triggers 'find-file-hook)
  (add-to-list 'super-save-triggers 'ace-window)
  (add-to-list 'super-save-triggers '+default/search-project)
  (super-save-mode t))
