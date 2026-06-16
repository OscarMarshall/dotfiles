;;; $DOOMDIR/config-web.el -*- lexical-binding: t; -*-

;;; JS

(after! js2-mode
  (setq js-chain-indent nil
        js-indent-align-list-continuation nil
        js-indent-first-init nil
        js-indent-level 2))


;;; Flycheck

(after! flycheck
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
                     (warning . ruby-rubylint))))
