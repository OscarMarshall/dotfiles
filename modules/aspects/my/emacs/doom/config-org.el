;;; $DOOMDIR/config-org.el -*- lexical-binding: t; -*-

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


;;; Deft

(setq deft-directory org-directory
      deft-recursive t)
