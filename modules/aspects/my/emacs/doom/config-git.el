;;; $DOOMDIR/config-git.el -*- lexical-binding: t; -*-

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
