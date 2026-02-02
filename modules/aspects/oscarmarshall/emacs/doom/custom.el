(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(cider-enable-nrepl-jvmti-agent t)
 '(custom-safe-themes
   '("ffafb0e9f63935183713b204c11d22225008559fa62133a69848835f4f4a758c" "7964b513f8a2bb14803e717e0ac0123f100fb92160dcf4a467f530868ebaae3e" "636b135e4b7c86ac41375da39ade929e2bd6439de8901f53f88fde7dd5ac3561" "0c08a5c3c2a72e3ca806a29302ef942335292a80c2934c1123e8c732bb2ddd77" "51c71bb27bdab69b505d9bf71c99864051b37ac3de531d91fdad1598ad247138" "cf922a7a5c514fad79c483048257c5d8f242b21987af0db813d3f0b138dfaf53" "4f1d2476c290eaa5d9ab9d13b60f2c0f1c8fa7703596fa91b235db7f99a9441b" "9efb2d10bfb38fe7cd4586afb3e644d082cbcdb7435f3d1e8dd9413cbe5e61fc" "c4bdbbd52c8e07112d1bfd00fee22bf0f25e727e95623ecb20c4fa098b74c1bd" "990e24b406787568c592db2b853aa65ecc2dcd08146c0d22293259d400174e37" "2f1518e906a8b60fac943d02ad415f1d8b3933a5a7f75e307e6e9a26ef5bf570" "aaa4c36ce00e572784d424554dcc9641c82d1155370770e231e10c649b59a074" "e72f5955ec6d8585b8ddb2accc2a4cb78d28629483ef3dcfee00ef3745e2292f" "99ea831ca79a916f1bd789de366b639d09811501e8c092c85b2cb7d697777f93" "e074be1c799b509f52870ee596a5977b519f6d269455b84ed998666cf6fc802a" default))
 '(flycheck-rubocoprc nil)
 '(flycheck-ruby-rubocop-executable "~/co/manage/script/rubocop_next_remote.rb")
 '(image-file-name-extensions
   '("png" "jpeg" "jpg" "gif" "tiff" "tif" "xbm" "xpm" "pbm" "pgm" "ppm" "pnm" "svg" "pdf"))
 '(magit-todos-insert-after '(bottom) nil nil "Changed by setter of obsolete option `magit-todos-insert-at'")
 '(rspec-spec-command "~/co/manage/script/spring_remote rspec")
 '(rspec-use-bundler-when-possible nil)
 '(rubocop-check-command "script/rubocop_next_remote.rb --format emacs")
 '(rubocop-prefer-system-executable t)
 '(ruby-deep-arglist nil)
 '(ruby-deep-indent-paren nil)
 '(ruby-deep-indent-paren-style nil)
 '(safe-local-variable-values
   '((cider-clojure-cli-global-options . "-A:dev")
     (cider-jack-in-nrepl-middlewares "cider.nrepl/cider-middleware" "refactor-nrepl.middleware/wrap-refactor" "shadow.cljs.devtools.server.nrepl/middleware")
     (flycheck-checker . jsx-tide)
     (flycheck-mode)
     (flycheck-ruby-rubocop-executable . "~/co/manage/script/rubocop_remote.rb")
     (rspec-spec-command . "~/co/manage/script/spring_remote rspec")
     (rspec-use-bundler-when-possible)
     (rubocop-autocorrect-command . "script/rubocop_remote.rb -A --format emacs")
     (rubocop-check-command . "script/rubocop_remote.rb --format emacs")
     (rubocop-prefer-system-executable . t)))
 '(typescript-indent-level 2)
 '(web-mode-code-indent-offset 2)
 '(web-mode-css-indent-offset 2)
 '(web-mode-markup-indent-offset 2)
 '(web-mode-sql-indent-offset 2))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(ts-fold-replacement-face ((t (:foreground unspecified :box nil :inherit font-lock-comment-face :weight light)))))
