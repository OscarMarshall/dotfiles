;;; $DOOMDIR/config-navigation.el -*- lexical-binding: t; -*-

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


;;; Expand Region

(map! "C-+" #'er/expand-region
      "C-0" #'er/mark-defun)


;;; Hide Show

(map! "C-M-H" #'hs-hide-block
      "C-M-S" #'hs-show-block
      "C-M-s-H" #'hs-hide-all
      "C-M-s-S" #'hs-show-all)


;;; Swiper

;; (map! [remap isearch-forward] #'swiper
;;       [remap isearch-backward] #'swiper-backward)
