;;; init.el --- My Emacs Initialization/Customization file  -*- lexical-binding: t -*-

;;; Commentary:

;; Init file for Emacs settings.
;;
;; Init compile command.
;; (byte-recompile-directory (expand-file-name "~/.emacs.d/") 0)

;;; Code:

(defconst emacs-start-time (current-time))
(message (format "[Startup time: %s]" (format-time-string "%Y/%m/%d %H:%M:%S")))
(eval-when-compile (require 'cl-lib))
(require 'server)
(when init-file-debug
  (setq debug-on-error t)
  (setq force-load-messages t))



;;;; -----------------------------------
;;;; Variables

(eval-and-compile
  (defvar package-dir-local "~/.local/emacs/elpa")
  (defvar shortcut-file-path "~/Dropbox/documents/notes/note.txt")
  (defvar my-recentf-file "~/.local/emacs/recentf")
  (defvar my-bookmarks-file "~/.local/emacs/bookmarks")

  ;; backup and auto-save
  (defvar backup-and-auto-save-dir-dropbox
    (expand-file-name "~/Dropbox/documents/apps/emacs/backups/"))
  (defvar backup-and-auto-save-dir-local
    (expand-file-name "~/.emacs.d/.backup/"))

  ;; org
  (defvar my-org-dir "~/Dropbox/documents/org")
  (defvar org-dir-local "~/.emacs.d/.org")
  ;; default is "my-org-dir/agenda"
  ;; if you want to add the agenda file,
  ;; please add it to the list below.
  (defvar my-org-agenda-files '())
  ;; org-journal
  (defvar my-org-journal-dir "~/Dropbox/documents/org/journal")

  (defvar clean-buffers-exclude-list
    (list "*Messages*"
          "*scratch*"
          "*dashboard*")
    "List of exclude buffer from the function `clean-buffers'."))



;;;; -----------------------------------
;;;; Functions

;; with-eval-after-load (Emacs 24.4 以上)
(unless (fboundp 'with-eval-after-load)
  (defmacro with-eval-after-load (file &rest body)
    `(eval-after-load ,file
       `(funcall (function ,(lambda () ,@body))))))

(defun clean-buffers ()
  "Kill all buffers except toolkit (*Messages*, *scratch*, etc).
And close other windows.  If you have buffers that you don't want to kill,
add it to the variable `clean-buffers-exclude-list'."
  (interactive)
  (when (yes-or-no-p "Kill all buffers? ")
    (let ((bufs))
      (setq bufs (mapcar 'buffer-name (buffer-list)))
      (cl-loop for b in bufs
               do
               (unless (string-equal (cl-subseq b 0 1) " ")
                 (unless (member b clean-buffers-exclude-list)
                   (kill-buffer b))))
      (delete-other-windows)
      (if (member "*dashboard*" bufs)
          (switch-to-buffer "*dashboard*")
        (switch-to-buffer "*scratch*")))))

(defun set-alpha (alpha)
  "Set ALPHA value of frame parameter."
  (interactive "^NAlpha value 0 - 100: ")
  (set-frame-parameter nil 'alpha alpha))

(defun set-my-default-faces ()
  "Can be used to set a default faces if the themes isn't installed."
  (interactive)
  (custom-set-faces
   '(default ((t (:background "gray13" :foreground "ghost white"))))
   '(font-lock-function-name-face ((t (:foreground "brightgreen"))))
   '(hl-line ((t (:background "gray25"))))
   '(web-mode-html-tag-bracket-face ((t (:foreground "ghost white"))))
   '(web-mode-html-tag-face ((t (:foreground "pale green"))))))

(defun window-resizer ()
  "Control window size and position."
  (interactive)
  (let ((dx (if (= (nth 0 (window-edges)) 0) 1
              -1))
        (dy (if (= (nth 1 (window-edges)) 0) 1
              -1))
        action c)
    (catch 'end-flag
      (while t
        (setq action
              (read-key-sequence-vector (format "size[%dx%d]"
                                                (window-width)
                                                (window-height))))
        (setq c (aref action 0))
        (cond ((= c ?l)
               (enlarge-window-horizontally dx))
              ((= c ?h)
               (shrink-window-horizontally dx))
              ((= c ?j)
               (enlarge-window dy))
              ((= c ?k)
               (shrink-window dy))
              ;; otherwise
              (t
               (let ((command (key-binding action)))
                 (when command
                   (call-interactively command)))
               (message "Quit")
               (throw 'end-flag t)))))))

(defvar other-window-or-split-hook nil)
(defun other-window-or-split ()
  "Call `other-window' or window split command.
If there is only one window open, `split-window-right' or
`split-window-below' will be called, depending on the size of frame.
If there are multiple windows, 'other-window' is called."
  (interactive)
  (if (one-window-p)
      (if (>= (* (frame-height) 2) (frame-width))
          (split-window-below)
        (split-window-right))
    (other-window 1))
  (run-hooks 'other-window-or-split-hook))

;; trailing-whitespace
(defun enable-show-trailing-whitespace ()
  "Enable display of trailing whitespace."
  (interactive) (setq show-trailing-whitespace t))
(defun disable-show-trailing-whitespace ()
  "Disable display of trailing whitespace."
  (interactive) (setq show-trailing-whitespace nil))
(defun toggle-show-trailing-whitespace ()
  "Toggle display of trailing whitespace."
  (interactive) (cl-callf null show-trailing-whitespace))

(defun shortcut-file (file)
  "Show a file FILE on the current buffer shortcut function."
  (interactive)
  (if (get-buffer file)
      (let ((buffer (get-buffer file)))
        (switch-to-buffer buffer)
        (message "%s" file))
    (find-file file)))

(defun kill-ring-save-buffer-file-path ()
  "View and copy the file path of the current buffer."
  (interactive)
  (let ((path (buffer-file-name)))
    (message "save path to kill-ring...%s" path)
    (kill-new path)))

(defun today ()
  "Enter today's date."
  (interactive)
  (insert (format-time-string "%Y%m%d" (current-time))))

(defun exit ()
  "Execute `delete-frame' if possible.
If not, if GUI, `iconify-frame' other than `save-buffers-kill-emacs'."
  (interactive)
  (if (delete-frame-enabled-p)
      (when (yes-or-no-p "Delete frame? ")
        (delete-frame))
    (progn
      (if (display-graphic-p)
          (iconify-frame)
        (save-buffers-kill-emacs)))))

(defun reset-frame-parameter (frame)
  "Reset FRAME height."
  (sleep-for 0.1)
  (set-frame-parameter frame 'height 32))

;; windows path & UNC path
;; quoted from https://w.atwiki.jp/ntemacs/pages/74.html
(defvar drvfs-alist)
(defun set-drvfs-alist ()
  "Set drvfs alist.
If you add mount after Emacs startup, Re-execute this function."
  (interactive)
  (setq drvfs-alist
        (mapcar (lambda (x)
                  (when (string-match "\\(.*\\)|\\(.*?\\)/?$" x)
                    (cons (match-string 1 x) (match-string 2 x))))
                (split-string (concat
                               ;; //wsl$ パス情報の追加
                               (when (or (not (string-match "Microsoft" (shell-command-to-string "uname -v")))
                                         (>= (string-to-number (nth 1 (split-string operating-system-release "-"))) 18362))
                                 (concat "/|" (shell-command-to-string "wslpath -m /")))
                               (shell-command-to-string
                                "mount | grep -E ' type (9p|drvfs) ' | grep -v '^tools on /init type 9p' | sed -r 's/(.*) on (.*) type (9p|drvfs) .*/\\2\\|\\1/' | sed 's!\\\\!/!g'"))
                              "\n" t))))

(defconst windows-path-style-regexp "\\`\\(.*/\\)?\\([a-zA-Z]:\\\\.*\\|[a-zA-Z]:/.*\\|\\\\\\\\.*\\|//.*\\)")

(defun windows-path-convert-file-name (name)
  "Convert windows-path NAME to a state can be interpreted by wsl."
  (setq name (replace-regexp-in-string windows-path-style-regexp "\\2" name t nil))
  (setq name (replace-regexp-in-string "\\\\" "/" name))
  (let ((case-fold-search t))
    (cl-loop for (mountpoint . source) in drvfs-alist
             if (string-match (concat "^\\(" (regexp-quote source) "\\)\\($\\|/\\)") name)
             return (replace-regexp-in-string "^//" "/" (replace-match mountpoint t t name 1))
             finally return name)))

(defun windows-path-run-real-handler (operation args)
  "Run OPERATION with ARGS."
  (let ((inhibit-file-name-handlers
         (cons 'windows-path-map-drive-hook-function
               (and (eq inhibit-file-name-operation operation)
                    inhibit-file-name-handlers)))
        (inhibit-file-name-operation operation))
    (apply operation args)))

(defun windows-path-map-drive-hook-function (operation name &rest args)
  "Run OPERATION on cygwin NAME with ARGS."
  (windows-path-run-real-handler
   operation
   (cons (windows-path-convert-file-name name)
         (if (stringp (car args))
             (cons (windows-path-convert-file-name (car args))
                   (cdr args))
           args))))



;;;; -----------------------------------
;;;; Environments

;;;;; load-path
(eval-and-compile
  (setq load-path (cons "~/.emacs.d/elisp" load-path)))

;;;;; network
(eval-and-compile
  (defvar gnutls-algorithm-priority "NORMAL:-VERS-TLS1.3")
  ;; proxy
  ;; ~/.local/emacs/proxy.elにプロキシ設定を書き込む
  (load "~/.local/emacs/proxy" t))

;;;;; package manager
(eval-and-compile
  ;; package.el
  (when (require 'package nil t)
    (setq package-user-dir package-dir-local)
    (setq package-archives
     '(("melpa" . "https://melpa.org/packages/")
       ;;("melpa-stable" . "https://stable.melpa.org/packages/")
       ;;("org" . "https://orgmode.org/elpa/")
       ;;("marmalade" . "https://marmalade-repo.org/packages/")
       ))
    (package-initialize)
    ;;(package-refresh-contents)
    (setq package-enable-at-startup nil)))

;;;;; use-package

;; - https://github.com/jwiegley/use-package
;;   非標準パッケージは use-package で管理する。（標準ライブラリは use-package では管理しない）
;; - 起動時の use-package の抑止
;;   init.el を外部に持ちだした時など、use-package を抑止したいときはEmacs を、オプション "--qq" で起動する。
;; - use-package が未インストールか、抑止されている場合は空マクロにする。

;; インストールされていなければインストールを実行
;; (unless (package-installed-p 'use-package)
;;  (package-refresh-contents)
;;  (package-install 'use-package))

(if init-file-debug
    (progn
      (defvar use-package-expand-minimally nil)
      (defvar use-package-verbose t))
  (progn
    (defvar use-package-expand-minimally t)
    (defvar use-package-verbose nil)))

(eval-and-compile
  ;; use-package-report
  (defvar use-package-minimum-reported-time 0)
  (defvar use-package-compute-statistics t)

  ;; option --qq (disable use-package)
  (if (member "--qq" command-line-args)
      (defmacro use-package (&rest _args))
    (progn
      ;; when use-package is not available
      (when (null (require 'use-package nil t))
        (message "`use-package' is unavailable!  Please install it via `M-x package-list-packages' if possible.")
        (defmacro use-package (&rest _args))))))

;; 後の startup.el におけるオプション認識エラーを防止
(add-to-list 'command-switch-alist '("--qq" . (lambda (switch) nil)))

(use-package use-package :ensure t :defer t) ; 形式的宣言

;; bind-key
;; bind-key* は、emulation-mode-map-alists を利用することにより、
;; minor-mode よりも優先させたいキーのキーマップを定義できる。
;; bind-key.el がない場合は普通のbind-key として振る舞う。
(use-package bind-key :ensure t :defer t)
(eval-and-compile
  (unless (require 'bind-key nil t)
    (defun bind-key (key cmd &optional keymap)
      (define-key (or keymap global-map) (kbd key) cmd))
    (defun bind-key* (key cmd) (global-set-key (kbd key) cmd))))

(use-package exec-path-from-shell
  :unless (eq system-type 'windows-nt)
  :ensure t :demand t
  :config
  (exec-path-from-shell-initialize))

(use-package auto-async-byte-compile
  :ensure t :defer t
  :hook (emacs-lisp-mode . enable-auto-async-byte-compile-mode)
  :custom (auto-async-byte-compile-exclude-files-regexp "/secret/"))

;;;;; flag
(defvar android-flag nil)
(when (string= "Android\n" (shell-command-to-string "uname -o"))
  (setq android-flag t))

;;;;; emacs-server
(unless (eq (server-running-p) 't)
  (server-start)
  ;; windows
  (when (eq window-system 'w32)
    (unless server-clients
      (add-hook 'after-init-hook 'iconify-frame))))


;;;; -----------------------------------
;;;; Libraries

(require 'color)
(use-package diminish :ensure t :demand t)
(use-package s :ensure t)
(use-package popup :ensure t :defer t)



;;;; -----------------------------------
;;;; General settings

(setq-default tab-width 4 indent-tabs-mode nil)
(setq default-directory "~/")
(setq scroll-conservatively 1)
(setq scroll-margin 5)
(setq mouse-wheel-scroll-amount
      '(1
        ((shift) . 5)))
(setq custom-file (locate-user-emacs-file "elisp/custom.el"))
(setq select-enable-clipboard t)
(setq confirm-kill-emacs 'yes-or-no-p)

;; terminal起動時のマウス設定
(unless (display-graphic-p) (xterm-mouse-mode t))

;; startup window size
(add-hook 'after-init-hook 'toggle-frame-maximized)
(add-hook 'after-make-frame-functions #'reset-frame-parameter)

;;;;; aliases
(defalias 'quit 'save-buffers-kill-emacs)

;;;;; my-keybinds
(bind-key "C-h" 'undo)
(bind-key "C-l" 'redo)
(bind-key "C-c |" 'split-window-right)
(bind-key "C-c -" 'split-window-below)
(bind-key "C-c k" 'delete-window)
(bind-key "C-c M-k" 'kill-buffer-and-window)
(bind-key "C-c w" 'exit)
(bind-key "C-o" 'other-window)
(bind-key "M-o" 'other-window)
(bind-key "C-c o" 'other-window-or-split)
(bind-key "C-i" 'indent-for-tab-command)
(bind-key "<zenkaku-hankaku>" 'toggle-input-method)
(bind-key "C-c n"
          '(lambda ()
             (interactive)
             (shortcut-file shortcut-file-path)))
(bind-key "C-c y c" 'kill-ring-save-buffer-file-path)

;; 最小化 -> C-x C-c
(global-unset-key (kbd "C-x C-c"))
(bind-key "C-x C-c" 'iconify-frame)

;; helm-for-filesが後に置き換え
;; 置き換えられない場合コチラがセット
(bind-key "C-x C-b" 'buffer-menu)

;;(windmove-default-keybindings)          ; use shift+arrow
;;(windmove-default-keybindings 'meta)    ; use alt+arrow

;;;;; backup, auto-save, lock
(eval-and-compile
  ;; backup (xxx~)

  ;; 保存するたびにバックアップを作る設定
  ;; https://www.ncaq.net/2018/04/19/10/57/08/
  (defun setq-buffer-backed-up-nil ()
    "Set nil to 'buffer-backed-up'."
    (interactive) (setq buffer-backed-up nil))
  (advice-add 'save-buffer :before 'setq-buffer-backed-up-nil)

  ;; Change backup directory
  (if (file-directory-p backup-and-auto-save-dir-dropbox)
      (add-to-list 'backup-directory-alist
                   (cons ".*" backup-and-auto-save-dir-dropbox))
    (add-to-list 'backup-directory-alist
                 (cons ".*" backup-and-auto-save-dir-local)))

  (setq make-backup-files t
        vc-make-backup-files t
        backup-by-copying t
        version-control t           ; 複数バックアップ
        kept-new-versions 30        ; 新しいバックアップをいくつ残すか
        kept-old-versions 0         ; 古いバックアップをいくつ残すか
        delete-old-versions t)      ; Delete out of range

  ;; auto-save (#xxx#)
  (setq auto-save-timeout 1             ; (def:30)
        delete-auto-save-files t        ; delete auto save file when successful completion.
        auto-save-list-file-prefix nil)
  (if (file-directory-p backup-and-auto-save-dir-dropbox)
      (setq auto-save-file-name-transforms
            `((".*", backup-and-auto-save-dir-dropbox t)))
    (setq auto-save-file-name-transforms
          `((".*", backup-and-auto-save-dir-local t))))

  ;; lockfile (.#xxx)
  (setq create-lockfiles nil))

;;;;; language

;; 文字・改行コード変更
;; C-x RET-f

;; character code
;; shift_jis
;; cp932
;; euc-jp
;; utf-8
;; utf-8-with-signature ; BOM付きutf-8

;; newline code
;; -dos  ; CR+LF
;; -mac  ; CR
;; -unix ; LF

(set-language-environment "Japanese")
(set-default 'buffer-file-cording-system 'utf-8-unix)
(prefer-coding-system 'utf-8-unix)
;; advanced settings of prefer-coding-system↑
;;(set-keyboard-coding-system 'utf-8-unix)
;;(set-file-name-coding-system 'utf-8-unix)
;;(set-terminal-coding-system 'utf-8-unix)

;;;;; wsl settings
(set-drvfs-alist)
(add-to-list 'file-name-handler-alist
             (cons windows-path-style-regexp
                   'windows-path-map-drive-hook-function))



;;;; -----------------------------------
;;;; Appearance settings

(setq inhibit-startup-message t)
(setq initial-scratch-message nil)
(menu-bar-mode 0)
(tool-bar-mode 0)
(when (fboundp 'set-scroll-bar-mode)
  (set-scroll-bar-mode nil))
;;(transient-mark-mode t)
(if (display-graphic-p) (set-alpha 98))

;;(setq display-time-day-and-date nil)
;;(setq display-time-24hr-format t)
;;(display-time)

(setq-default indicate-empty-lines nil)
(setq-default indicate-buffer-boundaries 'left)

(setq-default show-trailing-whitespace t)
(add-hook 'dashboard-mode-hook 'disable-show-trailing-whitespace)



;;;; -----------------------------------
;;;; Fonts

(when (member "Source Han Code JP" (font-family-list))
  (push '(font . "SourceHanCodeJp-9:weight=normal:slant=normal")
        default-frame-alist))
(when (member "SauceCodePro NF" (font-family-list))
  (push '(font . "SauceCodePro NF-10:weight=normal:slant=normal")
        default-frame-alist))

;; (when (display-graphic-p)
;;   (when (x-list-fonts "SourceHanCodeJP")
;;     ;;; create fontset
;;     (create-fontset-from-ascii-font "SourceHanCodeJp-9:weight=normal:slant=normal" nil "SourceHanCodeJp")
;;     ;;; set font
;;     (set-fontset-font "fontset-SourceHanCodeJp" 'unicode "SourceHanCodeJp" nil 'append)
;;     ;;; apply fontset to frame
;;     (add-to-list 'default-frame-alist '(font . "fontset-SourceHanCodeJp"))))



;;;; -----------------------------------
;;;; Themes

(when init-file-debug (message "Loading themes..."))

;;;;; doom-themes
(use-package doom-themes
  :ensure t
  :custom
  (doom-themes-enable-italic t)
  (doom-themes-enable-bold t)
  :config
  ;;(load-theme 'doom-dracula t)
  ;;(load-theme 'doom-challenger-deep)
  ;;(load-theme 'doom-horizon)
  ;;(load-theme 'doom-oceanic-next)
  (load-theme 'doom-vibrant t)

  (doom-themes-visual-bell-config)
  (when (display-graphic-p)             ; For cui, leave the settings to neotree
    (doom-themes-neotree-config))
  (doom-themes-org-config)

  (unless (display-graphic-p)
    (custom-set-faces
     '(default ((t (:background "unspecified-bg"))))
     ))

  (with-eval-after-load 'doom-dracula-theme
    (unless (display-grayscale-p)
      (custom-set-faces
       '(region ((t (:background "#00cd00"))))
       ))))

;;;;; check theme

;; Check if any enabled themes.
;; If nothing enabled themes, load my-default-faces.

(if custom-enabled-themes
    (when init-file-debug
      (message "Enabled themes: %s" custom-enabled-themes))
  (progn
    (when init-file-debug
      (message "Enabled themes is noghing!")
      (message "Loading my-default-faces...done"))
    (set-my-default-faces)))



;;;; -----------------------------------
;;;; Standard packages

;;;;; line number, highlight
;; linum, display-line-numbers, hl-line
(if (fboundp 'global-display-line-numbers-mode)
    (global-display-line-numbers-mode)
  (progn
    (global-hl-line-mode)
    (global-linum-mode)
    (defvar linum-format "%3d ")))

;; hl-line face
(with-eval-after-load 'doom-dracula-theme
  (unless (display-grayscale-p)
    (custom-set-faces
     '(hl-line ((t (:background "#303030"))))
     )))
(with-eval-after-load 'doom-vibrant-theme
  (unless (display-grayscale-p)
    (custom-set-faces
     '(hl-line ((t (:background "#303030"))))
     )))

;;;;; org
(defvar org-directory)
(defvar org-agenda-files)
(declare-function org-buffer-list "org")

;; cf. https://www.emacswiki.org/emacs/OrgMode#toc21
(defun mhatta/org-buffer-files ()
  "Return list of opened Org mode buffer files."
  (mapcar (function buffer-file-name)
          (org-buffer-list 'files)))

;; (bind-key "C-c c" 'org-capture)
(bind-key "M-n" 'org-next-visible-heading)
(bind-key "M-p" 'org-previous-visible-heading)

(push '("\\.org\\'" . org-mode) auto-mode-alist)

(if (file-directory-p my-org-dir)
    (progn
      (setq org-directory my-org-dir)
      (setq org-agenda-files
                    (list (concat my-org-dir "/agenda"))))
  (progn
    (setq org-directory org-dir-local)
    (setq org-agenda-files
                  (list org-dir-local))))
(setq org-agenda-files (append org-agenda-files my-org-agenda-files))

(defvar org-default-notes-file
              (concat org-directory "/notes.org"))

(defvar org-startup-truncated nil)

;; org-dir外のrefile設定(bufferで開いていれば指定可能)
(defvar org-refile-targets
              '((nil :maxlevel . 3)
                (mhatta/org-buffer-files :maxlevel . 1)
                (org-agenda-files :maxlevel . 3)))

;; templates
(defvar org-capture-templates
              '(("a" "Memoｃ⌒っﾟωﾟ)っφ ﾒﾓﾒﾓ..."
                 plain (file "memos.org")
                 "* %?%U"
                 :empty-lines 1 :jump-to-captured 1)
                ("n" "Notes....φ(・ω・｀ )ｶｷｶｷ"
                 entry (file+headline org-default-notes-file "NOTES")
                 "* %?%U"
                 :empty-lines 1)
                ("m" "Minutes( ´・ω) (´・ω・) (・ω・｀) (ω・｀ )"
                 entry (file+datetree "minutes.org" "MINUTES")
                 "* %?%U"
                 :empty-lines 1 :jump-to-captured 1)))

;;;;; outline
(bind-key "<backtab>" 'outline-toggle-children)
;; (add-hook 'emacs-lisp-mode-hook
;;           '(lambda ()
;;              (outline-minor-mode t)
;;              (outline-hide-body)))

;;;;; paren
(defvar show-paren-style 'mixed)
(defvar show-paren-when-point-inside-paren t)
(defvar show-paren-when-point-in-periphery t)
;; faces
(if (display-graphic-p)
    (progn
      (with-eval-after-load 'doom-dracula-theme
        (custom-set-faces
         '(show-paren-match ((t (:foreground "yellow"))))
         ))
      (with-eval-after-load 'doom-vibrant-theme
        (custom-set-faces
         '(show-paren-match ((t (:foreground "yellow"))))
         )))
  (progn
    (with-eval-after-load 'doom-dracula-theme
      (custom-set-faces
       '(show-paren-match ((nil (:background "yellow" :foreground "black"))))
       ))
    (with-eval-after-load 'doom-vibrant-theme
      (custom-set-faces
       '(show-paren-match ((nil (:background "yellow" :foreground "black"))))
       ))))
(show-paren-mode t)                ; illuminate corresponding brackets

(use-package recentf
  :custom
  (recentf-save-file my-recentf-file)
  (recentf-max-saved-items 500)
  (recentf-auto-cleanup 'never)
  (recentf-exclude '("/recentf\\'" "/bookmarks\\'")))

(use-package bookmark
  :custom
  (bookmark-file my-bookmarks-file))

(use-package whitespace
  :custom
  (whitespace-style '(face
                      spaces
                      tabs
                      ;;space-mark
                      ;;tab-mark
                      ))
  (whitespace-space-regexp "\\(\u3000+\\)") ; 全角スペースのみ表示
  :custom-face
  (whitespace-space ((t (:background "magenta"))))
  (whitespace-tab ((t (:background "brightblue"))))
  :config
  (global-whitespace-mode 1))

(use-package sh-script
  :mode ("\\.local_profile" . shell-script-mode))



;;;; -----------------------------------
;;;; Non-standard Packages

(use-package ace-isearch
  :ensure t
  :diminish ace-isearch-mode
  :hook (after-init . global-ace-isearch-mode)
  :custom
  (ace-isearch-use-jump nil)
  ;;(ace-isearch-jump-delay 1.0)
  ;;(ace-isearch-function 'ace-jump-word-mode)

  ;; if ace-isearch-jump-based-on-one-char is nil,
  ;; call ace-isearch-2-function (default:avy-goto-char-2)
  ;;(ace-isearch-jump-based-on-one-char t)

  ;; call ace-isearch-function-from-isearch,
  ;; when input >= ace-isearch-input-length
  (ace-isearch-input-length 6)
  (ace-isearch-function-from-isearch t)
  (ace-isearch-function-from-isearch 'helm-swoop-from-isearch)
  (ace-isearch-func-delay 0.0))

(use-package ace-jump-mode
  :ensure t
  :bind ("C-c a" . ace-jump-char-mode)
  :custom
  ;; ace-jump-word-modeのとき文字を尋ねないようにする
  (ace-jump-word-mode-use-query-char nil))

;; Make dependent with doom-themes.
;; Fonts install ->  "M-x all-the-icons-install-fonts"
(use-package all-the-icons :ensure t :defer t)

(use-package anzu
  :ensure t
  :diminish anzu-mode
  :hook (after-init . global-anzu-mode)
  :bind (([remap query-replace] . anzu-query-replace)
         ([remap query-replace-regexp] . anzu-query-replace-regexp))
  :custom
  (anzu-search-threshold 1000)
  (anzu-replace-threshold 1000)
  (anzu-minimum-input-length 3)
  :config
  (with-eval-after-load 'migemo
    (setq anzu-use-migemo t)))

(use-package avy
  :ensure t :defer t
  :bind ("M-g M-g" . avy-goto-line))

(use-package beacon
  :ensure t
  :diminish beacon-mode
  :hook (after-init . beacon-mode)
  :custom
  (beacon-size 20)
  (beacon-blink-duration 0.2)
  (beacon-blink-when-window-scrolls nil)
  :config
  (with-eval-after-load 'doom-dracula-theme
    (setq beacon-color "yellow")))

(use-package company
  :ensure t
  :bind (:map company-active-map
              ("C-p" . company-select-previous)
              ("C-n" . company-select-next))
  :hook
  (after-init . global-company-mode)
  (eshell-mode . (lambda () (company-mode -1)))
  :custom
  (company-idle-delay 0)
  (company-selection-wrap-around t)     ; 候補の最後の次は先頭に戻る
  (completion-ignore-case t)
  (company-require-match 'never)
  (company-dabbrev-downcase nil)        ; debbrev 小文字での補完
  (company-dabbrev-char-regexp "\\(\\sw\\|\\s_\\|_\\|-\\)"))

(use-package company-box
  :ensure t
  :hook (company-mode . company-box-mode)
  :config
  (with-eval-after-load 'all-the-icons
    (setq company-box-icons-alist 'company-box-icons-all-the-icons)))

(use-package company-quickhelp
  :ensure t
  :hook (company-mode . company-quickhelp-mode))

(use-package dashboard
  :ensure t
  :functions s-chop-prefix
  :custom
  (dashboard-banner-logo-title "\n\n")
  (dashboard-center-content t)
  (dashboard-page-separator "\n\n\n")

  ;; custom banner
  ;; You can be "path/to/your/image.png"
  ;; which displays whatever image you would prefer
  ;; ↓↓ custom banners ↓↓
  ;; 1: Ghost
  ;; 2: Isometric3
  ;; 3: Alligator
  ;; 4: ROMAN
  ;; 5: Pawp
  ;; 6: O8
  ;; 7: Blocks
  ;; 8: Graffiti
  ;; 9: Slant Relief
  ;; 10: Chunky
  ;; 11: Cricket
  (dashboard-startup-banner "~/.emacs.d/dashboard-banners/3.txt")

  ;; dashboard items
  (dashboard-items '((recents  . 10)
                     (bookmarks . 10)
                     ;;(agenda . 5)
                     ))

  ;; icon
  (dashboard-set-heading-icons t)
  (dashboard-set-file-icons t)

  ;; init-info (default: init time)
  (dashboard-set-init-info t)

  ;; footer
  (dashboard-set-footer t)
  ;;(dashboard-footer-messages '("Dashboard is pretty cool!"))
  ;;(dashboard-footer-icon (all-the-icons-octicon "dashboard"
  ;;                                              :height 1.1
  ;;                                              :v-adjust -0.05
  ;;                                              :face 'font-lock-keyword-face))
  :hook (after-init . dashboard-setup-startup-hook)
  :config
  (cl-case system-type
    (gnu/linux
     (setq dashboard-init-info
           (concat "Welcome to Emacs" emacs-version
                   " - "
                   (shell-command-to-string "uname -smo"))))
    (windows-nt
     (setq dashboard-init-info
           (concat "Welcome to Emacs" emacs-version
                   " - "
                   "Kernel " (s-chop-prefix "\n" (shell-command-to-string "cmd.exe /c ver")))))))

(use-package dimmer :disabled
  :ensure t
  :custom
  (dimmer-fraction 0.4)
  (dimmer-exclusion-regexp-list
       '(".*Minibuf.*"
         ".*Messages.*"
         ".*NeoTree.*"
         ".*auto-async.*"
         ".*Warnings.*"
         ".*magit-diff:.*"
         ".*Process List.*"
         ".*Help.*"))
  :config
  (dimmer-configure-company-box)
  (dimmer-configure-helm)
  (dimmer-configure-hydra)
  (dimmer-configure-magit)
  (dimmer-configure-which-key)
  (dimmer-mode t))

(use-package docker
  :ensure t
  :bind ("C-c d" . docker))

(use-package dockerfile-mode
  :ensure t
  :mode ("/Dockerfile\\'"))

(use-package docker-compose-mode :ensure t :defer t)

(use-package docker-tramp
  :ensure t :defer t
  :custom (docker-tramp-use-names t))

;; https://github.com/seagle0128/doom-modeline
;; Make dependent with doom-themes.
(use-package doom-modeline
  :ensure t
  :hook (after-init . doom-modeline-mode)
  :custom
  (doom-modeline-buffer-file-name-style 'truncate-with-project)
  (doom-modeline-minor-modes nil)
  (doom-modeline-buffer-encoding t)
  (doom-modeline-github-interval (* 30 60))

  ;; display env version
  (doom-modeline-env-version t)
  (doom-modeline-env-load-string "...")

  ;; icon
  (doom-modeline-icon (display-graphic-p))
  (doom-modeline-major-mode-icon t)
  (doom-modeline-major-mode-color-icon t)
  (doom-modeline-buffer-state-icon t)
  (doom-modeline-buffer-modification-icon nil) ; respect doom-modeline-buffer-state-icon
  (doom-modeline-unicode-fallback t)
  ;;(doom-modeline-persp-icon t)
  ;;(doom-modeline-modal-icon t)

  ;; persp
  ;;(doom-modeline-persp-name t)
  ;;(doom-modeline-display-default-persp-name nil)

  ;; lsp
  ;;(doom-modeline-lsp t)
  :config
  (line-number-mode 0)
  (column-number-mode 0))

(use-package elscreen
  :ensure t :defer nil
  ;;:no-require t
  ;;:functions (elscreen-create)
  :bind
  ("M-q" . elscreen-next)
  ("C-M-q" . elscreen-previous)
  :custom
  (elscreen-prefix-key (kbd "C-z"))
  ;;(elscreen-display-tab nil)
  (elscreen-tab-display-kill-screen nil)
  (elscreen-tab-display-control nil)
  :custom-face
  (elscreen-tab-background-face ((t (:background "aquamarine4"))))
  (elscreen-tab-other-screen-face ((t (:background "aquamarine4"))))
  :config
  (elscreen-start)
  ;;(elscreen-create) ; create scratch tab
  )

(use-package rotate
  :ensure t
  :bind ("C-c SPC" . rotate-layout))

;; dockerfile
;;   checker: hadolint(https://github.com/hadolint/hadolint)
;; python
;;   checker: flake8(pip install flake8)
;; yaml
;;   checker: yamllint(pip install yamllint)
;; markdonw
;;   checker: mdl(gem install mdl)
(use-package flycheck
  :ensure t
  :commands (flycheck-add-mode)
  :hook (after-init . global-flycheck-mode)
  :config
  (flycheck-add-mode 'tex-chktex 'yatex-mode)
  ;; (flycheck-define-checker yaml-docker-compose-yamllint
  ;;   "Yaml and Docker-compose flycheck-checker using yamllint in python package."
  ;;   :command ("yamllint" source)
  ;;   :error-patterns ((error line-start
  ;;                           (zero-or-more blank) line ":" column
  ;;                           (zero-or-more blank) "warning"
  ;;                           (zero-or-more blank) (message)
  ;;                           line-end)
  ;;                    (warning line-start
  ;;                             (zero-or-more blank) line ":" column
  ;;                             (zero-or-more blank) "error"
  ;;                             (zero-or-more blank) (message)
  ;;                             line-end))
  ;;   :modes (yaml-mode docker-compose-mode))
  ;; (add-to-list 'flycheck-checkers 'yaml-docker-compose-yamllint)
  )

(use-package git-gutter
  :ensure t
  :diminish git-gutter-mode
  :hook (after-init . global-git-gutter-mode)
  :custom
  (git-gutter:modified-sign "~")
  (git-gutter:added-sign    "+")
  (git-gutter:deleted-sign  "-")
  :custom-face
  (git-gutter:modified ((t (:background "#f1fa8c"))))
  (git-gutter:added    ((t (:background "#50fa7b"))))
  (git-gutter:deleted  ((t (:background "#ff79c6")))))

(use-package goto-chg
  :ensure t
  :bind (("<f8>" . goto-last-change)
         ("<M-f8>" . goto-last-change-reverse)))

(use-package helm
  :ensure t
  :diminish helm-migemo-mode
  :functions helm-migemo-mode
  :bind (("C-x C-f" . helm-find-files)
         ("C-c h" . helm-command-prefix)
         ("C-x C-b" . helm-for-files)
         ("M-x" . helm-M-x)
         ("M-y" . helm-show-kill-ring)
         :map helm-map
              ("<tab>" . helm-execute-persistent-action)
              ("C-c C-k" . helm-kill-selection-and-quit)
              ("C-i" . helm-execute-persistent-action)
              ("C-z" . helm-select-action))
  :custom
  ;; fuzzy matting
  (helm-buffers-fuzzy-matching t)
  (helm-apropos-fuzzy-match t)
  (helm-lisp-fuzzy-completion t)
  ;;(helm-M-x-fuzzy-match t)
  ;;(helm-recentf-fuzzy-match t)

  ;; helm-for-files
  (helm-for-files-preferred-list
   '(helm-source-buffers-list
     helm-source-recentf
     helm-source-bookmarks
     helm-source-file-cache
     helm-source-files-in-current-dir
     helm-source-bookmark-set
     ;;helm-source-locate
     ))
  :config
  (require 'helm-config)
  (with-eval-after-load 'migemo
    (helm-migemo-mode 1)))

(use-package helm-ag
  :ensure t
  :after helm
  :when (executable-find "ag")
  :bind ("M-s a" . helm-do-ag))

(use-package helm-flycheck
  :ensure t
  :after helm
  :bind (:map flycheck-mode-map
              ("C-c e" . 'helm-flycheck)))

(use-package helm-swoop
  :ensure t
  :after helm
  :commands (helm-swoop helm-multi-swoop)
  :bind (:map helm-swoop-map
              ("C-r" . helm-previous-line)
              ("C-s" . helm-next-line))
  :custom (helm-swoop-move-to-line-cycle nil))

(use-package hide-mode-line
  :ensure t
  :hook ((neotree-mode) . hide-mode-line-mode))

(use-package highlight-indent-guides
  :ensure t
  :when (display-graphic-p)
  :diminish highlight-indent-guides-mode
  :hook ((prog-mode . highlight-indent-guides-mode)
         (yaml-mode . highlight-indent-guides-mode))
  :custom
  (highlight-indent-guides-auto-enabled t)
  (highlight-indent-guides-responsive t)
  (highlight-indent-guides-method
   (if (display-graphic-p) 'bitmap 'character))
  (highlight-indent-guides-suppress-auto-error t))

(use-package hydra
  :ensure t :defer nil :no-require t
  :functions (winner-redo winner-undo
              git-gutter:previous-hunk git-gutter:next-hunk
              git-gutter:stage-hunk git-gutter:revert-hunk
              git-gutter:popup-hunk
              zoom-mode)
  :config
  (defhydra hydra-git-gutter (:hint nil)
    "
    ^Git-gutter^ | [_l_]: reload [_p_]: previous [_n_]: next [_s_]: stage [_r_]: revert [_d_]: diffinfo
    ^Magit^      | [_m_]: magit-status
    "
    ;; git-gutter
    ("l" git-gutter)
    ("p" git-gutter:previous-hunk)
    ("n" git-gutter:next-hunk)
    ("s" git-gutter:stage-hunk)
    ("r" git-gutter:revert-hunk)
    ("d" git-gutter:popup-hunk)
    ;; magit
    ("m" magit-status :exit t))

  (defhydra hydra-window-and-buffer-manager (:hint nil :exit t)
    "
    frame           | [_n_]: make [_w_]: delete
    window split    | [_2_]: split-below [_3_]: split-right
           resize   | [_r_]: resize [_c_]: balance
           manage   | [_0_]: delete [_1_]: delete-other [_h_]: redo [_l_]: undo
    buffer          | [_b_]: menu [_k_]: kill
    window & buffer | [_4_]: kill
    other           | [_z_]: zoom-mode
    "
    ;; frame
    ("n" make-frame)
    ("w" delete-frame)
    ;; window
    ("1" delete-other-windows)
    ("2" split-window-below)
    ("3" split-window-right)
    ("h" winner-undo :exit nil)
    ("l" winner-redo :exit nil)
    ("0" delete-window)
    ("r" window-resizer)
    ("c" balance-windows)
    ;; buffer
    ("b" buffer-menu)
    ("k" kill-buffer)
    ;; window & buffer
    ("4" kill-buffer-and-window)
    ;; other
    ("z" zoom-mode))

  (bind-key "C-c g" 'hydra-git-gutter/body)
  (bind-key "C-c x" 'hydra-window-and-buffer-manager/body))

;; https://github.com/jrosdahl/iflipb
(use-package iflipb
  :ensure t
  :bind
  ("<f12>" . iflipb-next-buffer)
  ("<S-f12>" . iflipb-previous-buffer)
  :custom
  (iflipb-ignore-buffers (list "^[*]" "^magit-process:"))
  (iflipb-wrap-around t))

(use-package indent-guide
  :ensure t
  :unless (display-graphic-p)
  :hook ((prog-mode . indent-guide-global-mode)
         (yaml-mode . indent-guide-global-mode))
  :custom (indent-guide-recursive t)
  :custom-face (indent-guide-face ((t (:foreground "brightwhite")))))

(use-package magit
  :ensure t
  :demand t
  ;; ↑↑↑ demand t について
  ;; shellからemacsclient経由でコミットメッセージの編集を行う際に
  ;; git-commitパッケージ等の読み込みが終わっている必要がある
  :custom
  (magit-log-margin
   '(t " %Y-%m-%d %H:%M:%S " magit-log-margin-width t 18)))

;; github flavored markdown
;; gem install commonmarker github-markup
(use-package markdown-mode
  :ensure t
  :bind (:map markdown-mode-map
              ("<tab>" . markdown-cycle)
              ("<S-tab>" . markdown-shifttab)
              ("M-n" . markdown-next-visible-heading)
              ("M-p" . markdown-previous-visible-heading))
  :mode (("\\.md\\'" . gfm-mode)
         ("\\.markdown\\'" . gfm-mode))
  :custom
  (markdown-command
   "commonmarker --extension=autolink,strikethrough,table,tagfilter,tasklist")
  (markdown-css-paths
   '("https://cdn.jsdelivr.net/npm/github-markdown-css/github-markdown.min.css"
     "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release/build/styles/github.min.css"))
  (markdown-xhtml-header-content "
<style>
  body {
    padding: 1rem 3rem;
  }

  @media only screen{
    body {
      border: 1px solid #ddd;
      margin: 1rem auto;
      max-width: 45rem;
      padding: 3rem;
    }
  }

  .markdown-body h1,
  .markdown-body h2,
  .markdown-body h3,
  .markdown-body h4,
  .markdown-body h5,
  .markdown-body h6,
  .markdown-body h7,
  .markdown-body strong {
    font-weight: 700;
  }
</style>

<script src=\"https://cdn.jsdelivr.net/gh/highlightjs/cdn-release/build/highlight.min.jp\"></script>

<script>hljs.initHighlightingOnLoad();</script>")
  (markdown-xhtml-body-preamble "<div class=\"markdown-body\">")
  (markdown-xhtml-body-epilogue "</div>"))

(use-package migemo
  :preface
  (defvar migemo-command (executable-find "cmigemo"))
  (defvar migemo-dictionary
    (locate-file "migemo-dict"
                 '("/usr/share/cmigemo/utf-8"))) ; debian
  (unless migemo-command
    (message "migemo: `cmigemo' is unavailable! Please install it via `sudo apt install cmigemo' if possible."))
  :if (and migemo-command migemo-dictionary)
  :ensure t :defer nil :no-require t
  :functions migemo-init
  :custom
  (migemo-options '("-q" "--emacs"))
  (migemo-coding-system 'utf-8-unix)
  (migemo-user-dictionary nil)
  (migemo-regex-dictionary nil)
  :config
  (load-library "migemo")
  (migemo-init))

;; require external package -> "emacs-mozc-bin"
(use-package mozc
  :if (executable-find "mozc_emacs_helper")
  :ensure t :defer t
  :custom
  (default-input-method "japanese-mozc")
  (mozc-leim-title "かな")
  :config
  (with-eval-after-load 'helm
    (bind-key "M-x" 'helm-M-x mozc-mode-map)
    ;;helm でミニバッファの入力時に IME の状態を継承しない
    (setq helm-inherit-input-method nil)
    ;; helm の検索パターンを mozc を使って入力した場合にエラーが発生することがあるのを改善する
    (advice-add 'mozc-helper-process-recv-response
                :around (lambda (orig-fun &rest args)
                          (cl-loop for return-value = (apply orig-fun args)
                                   if return-value return it)))
    ;; helm で候補のアクションを表示する際に IME を OFF にする
    (advice-add 'helm-select-action
                :before (lambda ()
                          (deactivate-input-method)))))

(use-package mozc-popup
  :ensure t
  :after mozc
  :custom (mozc-candidate-style 'popup))

(use-package neotree
  :ensure t
  :bind (("C-q" . neotree-toggle)
         :map neotree-mode-map
              ("a" . neotree-hidden-file-toggle)
              ("j" . neotree-next-line)
              ("k" . neotree-previous-line)
              ("h" . neotree-select-up-node)
              ("l" . neotree-change-root)
              ("C-b" . neotree-select-up-node)
              ("C-f" . neotree-change-root))
  :custom
  (neo-window-width 35)
  (neo-show-hidden-files t)
  (neo-smart-open t)
  :config
  ;; If the doom-themes is enabled, doom-themes-neotree-config
  ;; take priority over the settings below.
  (if (display-graphic-p)
      (if (member "all-the-icons" (font-family-list))
          (setq neo-theme 'icons)
        (setq neo-theme 'classic))
    (setq neo-theme 'nerd2)))

(use-package nyan-mode
  :ensure t
  :hook
  (after-init . nyan-mode)
  (nyan-mode . nyan-start-animation)
  :custom
  (nyan-bar-length 15)
  (nyan-cat-face-number 4)
  (nyan-minimum-window-width 50))

;; https://github.com/sabof/org-bullets
(use-package org-bullets
  :ensure t
  :hook (org-mode . org-bullets-mode)
  ;; :custom
  ;; (org-bullets-bullet-list '("" "" "" "" "" "" "" "" "" ""))
  )

(use-package org-journal
  :ensure t
  :bind ("C-c j" . org-journal-new-entry)
  :custom
  (org-journal-dir my-org-journal-dir)
  (org-journal-date-format "%Y-%m-%d %A")
  ;;(org-journal-time-format "%R")
  (org-journal-file-format "%Y%m%d.org")
  (org-journal-find-file 'find-file)
  (org-extend-today-until '3)
  :config
  ;; 折返しが起こったときの挙動の修正
  (add-hook 'visual-line-mode-hook
            '(lambda()
               (setq word-wrap nil))))

(use-package org-preview-html :ensure t :defer t)

(use-package rainbow-delimiters
  :ensure t
  :hook (prog-mode . rainbow-delimiters-mode)
  :config
  (cl-loop
   for index from 1 to rainbow-delimiters-max-face-count
   do
   (let ((face (intern (format "rainbow-delimiters-depth-%d-face" index))))
     (cl-callf color-saturate-name (face-foreground face) 30))))

(use-package recentf-ext :ensure t :defer nil)

(use-package redo+
  :pin manual :demand t
  :bind (("C-M-/" . redo)
         ("C-c /" . redo)
         ("C-M-_" . redo)))

(use-package restart-emacs
  :ensure t
  :commands (restart-emacs))

(use-package scratch-pop
  :ensure t
  :bind ("C-c s" . scratch-pop))

(use-package smart-newline
  :ensure t :defer t
  :diminish smart-newline-mode
  :hook ((emacs-lisp-mode . smart-newline-mode)
         (python-mode . smart-newline-mode)))

(use-package swap-buffers
  :ensure t
  :bind (("C-M-o" . swap-buffers-keep-focus)
         ("C-M-O" . swap-buffers))

  :config
  (defun swap-buffers-keep-focus ()
    (interactive)
    (swap-buffers t)))

(use-package synctex-for-evince-yatex
  :pin manual
  :if (executable-find "evince")
  :commands synctex-for-evince-dbus-initialize
  :functions YaTeX-define-key
  :init (synctex-for-evince-dbus-initialize)
  :hook (yatex-mode . (lambda ()        ; C-c C-e ; forward-search
                        (YaTeX-define-key
                         "e" 'synctex-for-evince-yatex-forward-search))))

(use-package typescript-mode :ensure t :defer t)

(use-package volatile-highlights
  :ensure t
  :diminish volatile-highlights-mode
  :hook (after-init . volatile-highlights-mode)
  :config
  ;; custom-face
  (with-eval-after-load 'doom-dracula-theme
    (custom-set-faces
     '(vhl/default-face ((nil (:foreground "#FF3333" :background "#FFCDCD"))))
     )))

(use-package web-mode
  :ensure t
  :mode ("\\.phtml\\'"
         "\\.tpl\\.php\\'"
         "\\.[gj]sp\\'"
         "\\.as[cp]x\\'"
         "\\.erb\\'"
         "\\.mustache\\'"
         "\\.djhtml\\'"
         "\\.html?\\'")
  :custom
  (web-mode-engines-alist
   '(("php" . "\\.phtml\\'")
     ("blade" . "\\.blade\\'"))))

(use-package which-key
  :ensure t
  :diminish which-key-mode
  :hook (after-init . which-key-mode))

(use-package winner
  :ensure t
  :commands (winner-redo winner-undo)
  :config (winner-mode 1))

(use-package yaml-mode
  :ensure t
  :mode ("\\.ya?ml\\'"))

(use-package yatex
  :ensure t
  :mode (("\\.tex\\'" . yatex-mode)
         ("\\.ltx\\'" . yatex-mode)
         ("\\.cls\\'" . yatex-mode)
         ("\\.sty\\'" . yatex-mode)
         ("\\.clo\\'" . yatex-mode)
         ("\\.bbl\\'" . yatex-mode))
  :custom
  (YaTeX-inhibit-prefix-letter t)
  (YaTeX-kanji-code nil)
  (YaTeX-latex-message-code 'utf-8)
  (YaTeX-use-LaTeX2e t)
  (YaTeX-use-AMS-LaTeX t)
  (tex-command "ptex2pdf -l -ot '-synctex=1'")
  (dvi2-command "evince")
  (bibtex-command "pbibtex")
  (tex-pdfview-command "evince"))

(use-package zoom
  :ensure t
  :bind ("C-c z" . zoom-mode)
  :config
  (defun auto-toggle-zoom ()
    (defvar bound-width 120)
    (if (>= (frame-width) bound-width)
        (when (eq zoom-mode nil)
          (custom-set-variables '(zoom-mode t))
          (message "zoom-mode enabled."))
      (when (eq zoom-mode t)
        (custom-set-variables '(zoom-mode nil))
        (message "zoom-mode disabled."))))
  ;;(add-hook 'other-window-or-split-hook 'auto-toggle-zoom)
  (custom-set-variables '(zoom-mode t)))



;;;; -----------------------------------
;;;; Finalization

;;;;; Load time mesurement of init.el
(let ((elapsed (float-time (time-subtract (current-time)
                                          emacs-start-time))))
  (message "Loading %s...done (%.3fs)" load-file-name elapsed))
(add-hook 'after-init-hook
          `(lambda ()
             (let ((elapsed
                    (float-time
                     (time-subtract (current-time) emacs-start-time))))
               (message "Loading %s...done (%.3fs) [after-init]"
                        ,load-file-name elapsed))) t)

;; (provide 'init)

;; Local Variables:
;; byte-compile-warnings: (not cl-functions obsolete)
;; End:

;;; init.el ends here
