;;; init.el --- My Emacs Initialization/Customization file  -*- lexical-binding: t -*-

;;; Commentary:

;; Init file for Emacs settings.
;;
;; Init compile command.
;; (byte-recompile-directory (expand-file-name "~/.emacs.d/") 0)

;;; Code:

(defconst emacs-start-time (current-time))
(message (format "[Startup time: %s]" (format-time-string "%Y/%m/%d %H:%M:%S")))
(eval-when-compile (require 'cl))



;; ++++++++++++++++++++++++++++++++++++++++++++++++++
;; Functions and Macros
;; ++++++++++++++++++++++++++++++++++++++++++++++++++

;;;; with-eval-after-load (Emacs 24.4 以上)
(unless (fboundp 'with-eval-after-load)
  (defmacro with-eval-after-load (file &rest body)
    `(eval-after-load ,file
       `(funcall (function ,(lambda () ,@body))))))

(defun set-alpha (value)
  "Set frame parameter 'alpha by VALUE."
  (interactive "nAlpha: ")
  (set-frame-parameter nil 'alpha (cons value '(90))))

(defun set-my-default-faces ()
  "Can be used to set a default faces if the themes isn't installed."
  (interactive)
  (custom-set-faces
   '(font-lock-function-name-face ((t (:foreground "brightgreen"))))
   '(hl-line ((t (:background "gray25"))))
   '(web-mode-html-tag-bracket-face ((t (:foreground "ghost white"))))
   '(web-mode-html-tag-face ((t (:foreground "pale green")))))
  (set-face-background 'default "gray13")
  (set-face-foreground 'default "ghost white"))

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

(defun other-window-or-split ()
  "If there is only one window, the 'split-window-horizontally' is called.
If there are multiple windows, the 'other-window' is called."
  (interactive)
  (when (one-window-p)
    (split-window-horizontally))
  (other-window 1))

;;;; trailing-whitespace
(defun enable-show-trailing-whitespace  ()
  "Enable display of trailing whitespace."
  (interactive) (setq show-trailing-whitespace t))
(defun disable-show-trailing-whitespace ()
  "Disable display of trailing whitespace."
  (interactive) (setq show-trailing-whitespace nil))
(defun toggle-show-trailing-whitespace ()
  "Toggle display of trailing whitespace."
  (interactive) (callf null show-trailing-whitespace))



;; ++++++++++++++++++++++++++++++++++++++++++++++++++
;; Environments
;; ++++++++++++++++++++++++++++++++++++++++++++++++++

(eval-and-compile

  ;;;; Package Manager
  ;;; package.el
  (when (require 'package nil t)
    (set-variable
     'package-archives
     '(("melpa" . "https://melpa.org/packages/")
       ;;("melpa-stable" . "https://stable.melpa.org/packages/")
       ;;("org" . "https://orgmode.org/elpa/")
       ;;("maralade" . "https://marmalade-repo.org/packages/")
       ))
    (package-initialize)
    (package-refresh-contents)
    (set-variable 'package-enable-at-startup nil))

  ;;;; load-path
  (setq load-path (cons "~/.emacs.d/elisp" load-path))

  ;;;; proxy
  ;; ~/.emacs.d/elisp/secret/myproxy.elにプロキシ設定を書き込む
  (load "secret/myproxy" t)

  ;;;; debug
  (if init-file-debug
      (progn
        (setq debug-on-error t)
        (setq force-load-messages t)
        (set-variable 'use-package-verbose t)
	    (set-variable 'use-package-expand-minimally nil)
	    (set-variable 'use-package-compute-statistics t))
    (progn
      (set-variable 'use-package-verbose nil)
      (set-variable 'use-package-expand-minimally t))))

;;;; use-package
;; - https://github.com/jwiegley/use-package
;;   非標準パッケージは use-package で管理する。（標準ライブラリは use-package では管理しない）
;; - 起動時の use-package の抑止
;;   init.el を外部に持ちだした時など、use-package を抑止したいときはEmacs を、オプション "--qq" で起動する。
;; - use-package が未インストールか、抑止されている場合は空マクロにする。
;;; インストールされていなければインストールを実行
;;(unless (package-installed-p 'use-package)
;;  (package-refresh-contents)
;;  (package-install 'use-package))
;;;
(eval-and-compile
  (when (or (member "--qq" command-line-args)
            (null (require 'use-package nil t)))
    (warn "`use-package' is unavailable!  Please install it via `M-x list-packages' if possible.")
    (defmacro use-package (&rest _args))))
;; 後の startup.el におけるオプション認識エラーを防止
(add-to-list 'command-switch-alist '("--qq" . (lambda (switch) nil)))
(use-package use-package :ensure t :defer t) ; 形式的宣言

;;;; bind-key
;; bind-key* は、emulation-mode-map-alists を利用することにより、
;; minor-mode よりも優先させたいキーのキーマップを定義できる。
;; bind-key.el がない場合は普通のbind-key として振る舞う。
(use-package bind-key :ensure t :defer t)
(eval-and-compile
  (unless (require 'bind-key nil t)
    (defun bind-key (key cmd &optional keymap)
      (define-key (or keymap global-map) (kbd key) cmd))
    (defun bind-key* (key cmd) (global-set-key (kbd key) cmd))))



;; ++++++++++++++++++++++++++++++++++++++++++++++++++
;; Settings
;; ++++++++++++++++++++++++++++++++++++++++++++++++++

;; -------------------------------------
;; General

;;;; tab幅
(setq-default tab-width 4 indent-tabs-mode nil)

;;;; scroll
(set-variable 'mouse-wheel-scroll-amount '(5 ((shift) . 1) ((control))))
(set-variable 'mouse-wheel-progressive-speed nil)
(set-variable 'scroll-conservatively 30)
(set-variable 'scroll-margin 5)

;;;; windmove setting
;;(windmove-default-keybindings)          ; use shift+arrow
;;(windmove-default-keybindings 'meta)    ; use alt+arrow

;;;; my-keybinds
(bind-key "C-o" 'other-window-or-split)
(bind-key "C-i" 'indent-for-tab-command)
(bind-key "<zenkaku-hankaku>" 'toggle-input-method)
;;; "C-x C-c" -> exit
(global-unset-key (kbd "C-x C-c"))
(defalias 'exit 'save-buffers-kill-emacs)
;;;
;; helm-for-filesが後に置き換え
;; 置き換えられない場合コチラがセット
(bind-key "C-x C-b" 'buffer-menu)

(eval-and-compile
  ;;;; backup and auto-save dir
  (defvar backup-and-auto-save-dir-dropbox
    (expand-file-name "~/Dropbox/backup/emacs/"))
  (defvar backup-and-auto-save-dir-local
    (expand-file-name "~/.emacs.d/.backup/"))

  ;;;; backup (xxx~)
  ;;; 保存するたびにバックアップを作る設定
  ;;; https://www.ncaq.net/2018/04/19/10/57/08/
  (defun setq-buffer-backed-up-nil ()
    "Set nil to 'buffer-backed-up'."
    (interactive) (setq buffer-backed-up nil))
  (advice-add 'save-buffer :before 'setq-buffer-backed-up-nil)
  ;;; Change backup directory
  (if (file-directory-p backup-and-auto-save-dir-dropbox)
      (add-to-list 'backup-directory-alist
                   (cons ".*" backup-and-auto-save-dir-dropbox))
    (add-to-list 'backup-directory-alist
                 (cons ".*" backup-and-auto-save-dir-local)))
  ;;; Save multiple backupfiles
  (setq make-backup-files t
        vc-make-backup-files t
        backup-by-copying t
        version-control t           ; 複数バックアップ
        kept-new-versions 30        ; 新しいバックアップをいくつ残すか
        kept-old-versions 0         ; 古いバックアップをいくつ残すか
        delete-old-versions t)      ; Delete out of range

  ;;;; auto-save (#xxx#)
  (setq auto-save-timeout 1             ; (def:30)
        delete-auto-save-files t ; delete auto save file when successful completion.
        auto-save-list-file-prefix nil)
  (if (file-directory-p backup-and-auto-save-dir-dropbox)
      (setq auto-save-file-name-transforms
            `((".*", backup-and-auto-save-dir-dropbox t)))
    (setq auto-save-file-name-transforms
          `((".*", backup-and-auto-save-dir-local t))))

  ;;;; lockfile (.#xxx)
  (setq create-lockfiles nil))

;;;; language
(set-language-environment "Japanese")
(prefer-coding-system 'utf-8)
(set-keyboard-coding-system 'utf-8)
(set-file-name-coding-system 'utf-8)
(set-terminal-coding-system 'utf-8)
(set-default 'buffer-file-cording-system 'utf-8)

;;;; saving customization
(setq custom-file (locate-user-emacs-file "elisp/custom.el"))

;;;; terminalでのマウス使用
(unless (display-graphic-p) (xterm-mouse-mode t))

;; -------------------------------------
;; Appearance

;;;; hide startup message
(setq inhibit-startup-message t)

;;;; hide *scratch* buffer message
(setq initial-scratch-message nil)

;;;; hide menu bar
(menu-bar-mode 0)

;;;; hide tool bar
(if (display-graphic-p)
    (tool-bar-mode 0))

;;;; show full path in title
(setq frame-title-format "%f")

;;;; region highlight
(transient-mark-mode t)

;;;; alpha
(if (display-graphic-p) (set-alpha 90))

;;;; window size settings
(add-to-list 'initial-frame-alist '(fullscreen . maximized))

;;;; display-time
;;(setq display-time-day-and-date nil)
;;(setq display-time-24hr-format t)
;;(display-time)

;;;; indicater
(setq-default indicate-empty-lines nil)
(setq-default indicate-buffer-boundaries 'left)

;;;; visualization of space and tab
;;(global-whitespace-mode 1)

;;;; 行末の空白表示
(setq-default show-trailing-whitespace nil)
(add-hook 'prog-mode-hook 'enable-show-trailing-whitespace)
(add-hook 'org-mode-hook 'enable-show-trailing-whitespace)



;; ++++++++++++++++++++++++++++++++++++++++++++++++++
;; Libraries
;; ++++++++++++++++++++++++++++++++++++++++++++++++++

(use-package pkg-info :ensure t :defer t)
(use-package diminish :ensure t :demand t)
;;(use-package use-package-ensure-system-package :ensure t :demand t)



;; ++++++++++++++++++++++++++++++++++++++++++++++++++
;; Fonts
;; ++++++++++++++++++++++++++++++++++++++++++++++++++

(when (member "Source Han Code JP" (font-family-list))
  (push '(font . "SourceHanCodeJp-9:weight=normal:slant=normal")
        default-frame-alist))
;; (when (display-graphic-p)
;;   (when (x-list-fonts "SourceHanCodeJP")
;;     ;;; create fontset
;;     (create-fontset-from-ascii-font "SourceHanCodeJp-9:weight=normal:slant=normal" nil "SourceHanCodeJp")
;;     ;;; set font
;;     (set-fontset-font "fontset-SourceHanCodeJp" 'unicode "SourceHanCodeJp" nil 'append)
;;     ;;; apply fontset to frame
;;     (add-to-list 'default-frame-alist '(font . "fontset-SourceHanCodeJp"))))



;; ++++++++++++++++++++++++++++++++++++++++++++++++++
;; Themes
;; ++++++++++++++++++++++++++++++++++++++++++++++++++

(when init-file-debug (message "Loading themes..."))

;;;; doom-themes
(use-package doom-themes
  :ensure t
  :config
  (setq doom-themes-enable-italic t
        doom-themes-enable-bold t)
 (load-theme 'doom-dracula t)
  (doom-themes-visual-bell-config)
  (doom-themes-neotree-config)
  (doom-themes-org-config)
  (with-eval-after-load 'doom-dracula-theme
    (unless (display-grayscale-p)
      (custom-set-faces
       '(region ((t (:background "#00cd00"))))
       ))))

;;;; ice-berg-theme
(use-package iceberg-theme :disabled
  :config
  (iceberg-theme-create-theme-file)
  (load-theme 'solarized-iceberg-dark t))

;;;; zenburn-theme
(use-package zenburn-theme :disabled
  :config
  (load-theme 'zenburn t))

;;;
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



;; ++++++++++++++++++++++++++++++++++++++++++++++++++
;; Packages
;; ++++++++++++++++++++++++++++++++++++++++++++++++++

;; -------------------------------------
;; standard packages

;;;; display-line-numbers.el
;;;; linum.el
(if (fboundp 'global-display-line-numbers-mode)
    (global-display-line-numbers-mode)
  (progn
    (global-linum-mode)
    (set-variable 'linum-format "%3d ")))

;;;; hl-line.el
(global-hl-line-mode)
(with-eval-after-load 'doom-dracula-theme
  (unless (display-grayscale-p)
    (custom-set-faces
     '(hl-line ((t (:background "#3a3a3a"))))
     )))

;;;; org.el
(defvar org-directory)
(declare-function org-buffer-list "org")
;;; cf. https://www.emacswiki.org/emacs/OrgMode#toc21
(defun mhatta/org-buffer-files ()
  "Return list of opened Org mode buffer files."
  (mapcar (function buffer-file-name)
          (org-buffer-list 'files)))
;;; org-directory内の(file)を確認できる関数
(defun show-org-buffer (file)
  "Show an org-file FILE on the current buffer."
  (interactive)
  (if (get-buffer file)
      (let ((buffer (get-buffer file)))
        (switch-to-buffer buffer)
        (message "%s" file))
    (find-file (concat org-directory file))))
;;; key binds
(bind-key "C-c c" 'org-capture)
(bind-key "C-c n" '(lambda () (interactive) (show-org-buffer "/notes.org")))
;;; mode
(push '("\\.org\\'" . org-mode) auto-mode-alist)
;;; custom
(if (file-directory-p "~/Dropbox/document/org")
    (progn
      (setq org-directory "~/Dropbox/document/org")
      (set-variable 'org-agenda-files
                    '("~/Dropbox/document/org/agenda")))
  (progn
    (setq org-directory "~/.emacs.d/.org")
    (set-variable 'org-agenda-files
                  '("~/.emacs.d/.org"))))
(set-variable 'org-default-notes-file
              (concat org-directory "/notes.org"))
(set-variable 'org-startup-truncated nil)
;; org-dir外のrefile設定(bufferで開いていれば指定可能)
(set-variable 'org-refile-targets
              '((nil :maxlevel . 3)
                (mhatta/org-buffer-files :maxlevel . 1)
                (org-agenda-files :maxlevel . 3)))
;; templates
(set-variable 'org-capture-templates
              '(("a" "Memoｃ⌒っﾟωﾟ)っφ　ﾒﾓﾒﾓ..."
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

;;;; paren.el
(show-paren-mode t)                ; illuminate corresponding brackets
(set-variable 'show-paren-style 'mixed)
(set-variable 'show-paren-when-point-inside-paren t)
(set-variable ' show-paren-when-point-in-periphery t)
;;; custom-face
(with-eval-after-load 'doom-dracula-theme
  (custom-set-faces
   '(show-paren-match ((nil (:background "#44475a" :foreground "#f1fa8c"))))
   ))

;;;; recentf.el
(set-variable 'recentf-max-saved-items 500)
(set-variable 'recentf-auto-cleanup 'never)
(set-variable 'recentf-exclude
              '("/recentf\\'" "/bookmarks\\'"))

;; -------------------------------------
;; Non-standard Packages

;;;; ace-isearch
(use-package ace-isearch
  :ensure t
  :diminish ace-isearch-mode
  :hook (after-init . global-ace-isearch-mode)
  :config (setq ace-isearch-jump-delay 0.7))

;;;; ace-jump-mode
(use-package ace-jump-mode
  :ensure t :defer t
  :config
  (setq ace-jump-mode-move-keys
        (append "asdfghjkl;:]qwertyuiop@zxcvbnm,." nil))
  ;; ace-jump-word-modeのとき文字を尋ねないようにする
  (setq ace-jump-word-mode-use-query-char nil))

;;;; all-the-icons
;; Make dependent with doom-themes.
;; Fonts install ->  "M-x all-the-icons-install-fonts"
(use-package all-the-icons :ensure t :defer t)

;;;; anzu
(use-package anzu
  :ensure t
  :diminish anzu-mode
  :hook (after-init . global-anzu-mode)
  :bind (([remap query-replace] . anzu-query-replace)
         ([remap query-replace-regexp] . anzu-query-replace-regexp))
  :config
  (setq anzu-search-threshold 1000)
  (setq anzu-replace-threshold 1000)
  (setq anzu-minimum-input-length 3)
  (with-eval-after-load 'migemo
    (setq anzu-use-migemo t)))

(use-package auto-async-byte-compile
  :ensure t :defer t
  :hook (emacs-lisp-mode . enable-auto-async-byte-compile-mode)
  :config
  (set-variable 'auto-async-byte-compile-exclude-files-regexp "/secret/"))

;;;; beacon
(use-package beacon
  :ensure t
  :if (version<= "2.14" (pkg-info-version-info 'seq))
  :diminish beacon-mode
  :hook (after-init . beacon-mode)
  :config
  (set-variable 'beacon-size 20)
  (set-variable 'beacon-blink-duration 0.2)
  (set-variable 'beacon-blink-when-window-scrolls nil)
  (with-eval-after-load 'doom-dracula-theme
    (set-variable 'beacon-color "yellow")))

;;;; company.el
(use-package company
  :ensure t :demand t
  :bind (("<tab>" . company-indent-or-complete-common)
         :map company-active-map
              ("C-p" . company-select-previous)
              ("C-n" . company-select-next))
  :custom
  (company-idle-delay 0)                ; 手動補完
  (company-selection-wrap-around t)     ; 候補の最後の次は先頭に戻る
  (completion-ignore-case t)
  (company-require-match 'never)
  (company-backends '((company-capf company-dabbrev)
                      ;;company-bbdb
                      ;;company-eclim
                      company-semantic
                      ;;company-clang
                      ;;company-xcode
                      ;;company-cmake
                      company-files
                      (company-dabbrev-code company-gtags
                                            company-etags company-keywords)
                      ;;company-oddmuse
                      ))
  :config
  (global-company-mode))

;;;; company-box.el
(use-package company-box
  :ensure t
  :if (version<= "26" emacs-version)
  :hook (company-mode . company-box-mode)
  :config
  (with-eval-after-load 'all-the-icons
    (set-variable 'company-box-icons-alist 'company-box-icons-all-the-icons)))

;;;; company-quickhelp.el
(use-package company-quickhelp
  :ensure t
  :hook (company-mode . company-quickhelp-mode))

;;;; dashboard
(use-package dashboard
  :ensure t
  :if (version<= "25.3" emacs-version)
  :custom
  ;;; set the title
  (dashboard-banner-logo-title nil)
  ;;; custom banner
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
  (dashboard-startup-banner 10)
  ;;; dashboard items
  (dashboard-items '((recents  . 15)
                     ;;(bookmarks . 5)
                     (agenda . 5)))
  ;;; centering
  (dashboard-center-content t)
  ;;; icon
  (dashboard-set-heading-icons t)
  (dashboard-set-file-icons t)
  ;;; init-info (default: init time)
  (dashboard-set-init-info t)
  ;;; footer
  (dashboard-set-footer t)
  ;;(dashboard-footer-messages '("Dashboard is pretty cool!"))
  ;;(dashboard-footer-icon (all-the-icons-octicon "dashboard"
  ;;                                              :height 1.1
  ;;                                              :v-adjust -0.05
  ;;                                              :face 'font-lock-keyword-face))
  :hook (after-init . dashboard-setup-startup-hook)
  :config
  (when (eq system-type 'gnu/linux)
    (set-variable 'dashboard-init-info
                  (concat "Welcome to Emacs " emacs-version
                          " - "
                          "Kernel " (shell-command-to-string "uname -smo")))))

;;;; docker.el
(use-package docker
  :ensure t
  :bind ("C-c d" . docker))

;;;; dockerfile-mode.el
(use-package dockerfile-mode
  :ensure t
  :mode ("/Dockerfile\\'"))

;;;; docker-compose-mode
;; yaml-modeも兼ねる
(use-package docker-compose-mode :ensure t :defer t)

;;;; docker-tramp.el
(use-package docker-tramp
  :ensure t :defer t
  :config (set-variable 'docker-tramp-use-names t))

;;;; doom-modeline
;; https://github.com/seagle0128/doom-modeline
;; Make dependent with doom-themes.
(use-package doom-modeline
  :ensure t
  :hook (after-init . doom-modeline-mode)
  :config
  (line-number-mode 0)
  (column-number-mode 0)
  (setq doom-modeline-buffer-file-name-style 'truncate-with-project)
  (setq doom-modeline-minor-modes nil)
  (setq doom-modeline-buffer-encoding nil)
  ;;; display env version
  (setq doom-modeline-env-version t)
  (setq doom-modeline-env-load-string "...")
  ;;; icon
  (setq doom-modeline-icon (display-graphic-p))
  (setq doom-modeline-major-mode-icon t)
  (setq doom-modeline-major-mode-color-icon t)
  (setq doom-modeline-buffer-state-icon t)
  (setq doom-modeline-buffer-modification-icon t) ; respect doom-modeline-buffer-state-icon
  (setq doom-modeline-persp-icon t)
  (setq doom-modeline-modal-icon t)
  (setq doom-modeline-unicode-fallback nil)
  (setq doom-modeline-github-interval (* 30 60))
  ;;; persp
  ;;(setq doom-modeline-persp-name t)
  ;;(setq doom-modeline-display-default-persp-name nil)
  ;;; lsp
  ;;(setq doom-modeline-lsp t)
  )

;;;; elscreen
(use-package elscreen
  :ensure t :defer nil :no-require t
  :functions (elscreen-create)
  :bind ("<f5>" . elscreen-next)
  :config
  ;;; Turn off peripheral functions of tab.
  (set-variable 'elscreen-display-tab nil)
  (set-variable 'elscreen-tab-display-kill-screen nil)
  (set-variable 'elscreen-tab-display-control nil)
  ;;; init
  (elscreen-start)
  (elscreen-create))

;;;; flycheck.el
;; dockerfile
;;   checker: hadolint(https://github.com/hadolint/hadolint)
;; python
;;   checker: flake8(pip install flake8)
(use-package flycheck
  :ensure t
  :hook ((emacs-lisp-mode . flycheck-mode)
         (dockerfile-mode . flycheck-mode)
         (python-mode . flycheck-mode)))

;;;; git-gutter
(use-package git-gutter
  :ensure t
  :diminish git-gutter-mode
  :hook (after-init . global-git-gutter-mode)
  :custom-face
  (git-gutter:modified ((t (:background "#f1fa8c"))))
  (git-gutter:added    ((t (:background "#50fa7b"))))
  (git-gutter:deleted  ((t (:background "#ff79c6"))))
  :config
  (set-variable 'git-gutter:modified-sign "~")
  (set-variable 'git-gutter:added-sign    "+")
  (set-variable 'git-gutter:deleted-sign  "-"))

;;;; helm
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
  :config
  (require 'helm-config)
  (with-eval-after-load 'migemo
    (helm-migemo-mode 1))
  ;;; fuzzy matting
  (set-variable 'helm-buffers-fuzzy-matching t)
  (set-variable 'helm-apropos-fuzzy-match t)
  (set-variable 'helm-lisp-fuzzy-completion t)
  ;;(set-variable 'helm-M-x-fuzzy-match t)
  ;;(set-variable 'helm-recentf-fuzzy-match t)
  ;;; helm-for-files
  (set-variable 'helm-for-files-preferred-list
        '(helm-source-buffers-list
          helm-source-recentf
          helm-source-bookmarks
          helm-source-file-cache
          helm-source-files-in-current-dir
          helm-source-bookmark-set
          ;;helm-source-locate
          )))

;;;; helm-flycheck.el
(use-package helm-flycheck
  :ensure t
  :bind (:map flycheck-mode-map
              ("C-c ! h" . 'helm-flycheck)))

;;;; helm-swoop
(use-package helm-swoop
  :ensure t
  :after helm
  :commands (helm-swoop helm-multi-swoop)
  :bind (:map helm-swoop-map
              ("C-r" . helm-previous-line)
              ("C-s" . helm-next-line))
  :config
  (setq helm-swoop-move-to-line-cycle nil))

;;;; highlight-indent-guides
(use-package highlight-indent-guides
  :ensure t
  :diminish highlight-indent-guides-mode
  :hook ((prog-mode . highlight-indent-guides-mode)
         (yaml-mode . highlight-indent-guides-mode))
  :custom
  (highlight-indent-guides-auto-enabled t)
  (highlight-indent-guides-responsive t)
  (highlight-indent-guides-method
   (if (display-graphic-p) 'bitmap 'character))
  (highlight-indent-guides-suppress-auto-error t))


;;;; hydra
(use-package hydra
  :ensure t :defer nil :no-require t
  :functions (winner-redo winner-undo
                          git-gutter:previous-hunk git-gutter:next-hunk
                          git-gutter:stage-hunk git-gutter:revert-hunk
                          git-gutter:popup-hunk)
  :config
  (defhydra hydra-git-gutter (:hint nil)
    "
    ^Git-gutter^ | [_l_]: reload [_p_]: previous [_n_]: next [_s_]: stage [_r_]: revert [_d_]: diffinfo
    ^Magit^      | [_m_]: magit-status
    "
    ;;; git-gutter
    ("l" git-gutter)
    ("p" git-gutter:previous-hunk)
    ("n" git-gutter:next-hunk)
    ("s" git-gutter:stage-hunk)
    ("r" git-gutter:revert-hunk)
    ("d" git-gutter:popup-hunk)
    ;;; magit
    ("m" magit-status :exit t))
  (defhydra hydra-window-and-buffer-manager (:hint nil :exit t)
    "
    frame           | [_n_]: make [_w_]: delete
    window split    | [_2_]: split-below [_3_]: split-right
           resize   | [_r_]: resize [_c_]: balance
           manage   | [_0_]: delete [_1_]: delete-other [_h_]: redo [_l_]: undo
    buffer          | [_b_]: menu [_k_]: kill
    window & buffer | [_4_]: kill
    "
    ;;; frame
    ("n" make-frame)
    ("w" delete-frame)
    ;;; window
    ("1" delete-other-windows)
    ("2" split-window-below)
    ("3" split-window-right)
    ("h" winner-undo :exit nil)
    ("l" winner-redo :exit nil)
    ("0" delete-window)
    ("r" window-resizer)
    ("c" balance-windows)
    ;;; buffer
    ("b" buffer-menu)
    ("k" kill-buffer)
    ;;; window & buffer
    ("4" kill-buffer-and-window))
  (bind-key "C-c g" 'hydra-git-gutter/body)
  (bind-key "C-c x" 'hydra-window-and-buffer-manager/body))

;;;; iflipb
;; https://github.com/jrosdahl/iflipb
(use-package iflipb
  :ensure t
  :bind (("M-o" . iflipb-next-buffer)
         ("M-O" . iflipb-previous-buffer))
  :config
  (setq iflipb-ignore-buffers (list "^[*]" "^magit-process:"))
  (setq iflipb-wrap-around t))

;;;; magit.el
(use-package magit :ensure t :defer t)

;;;; markdown-mode
(use-package markdown-mode
  :ensure t
  :mode ("\\.md\\'"
         "\\.markdown\\'"))

;;;; migemo
(defvar migemo-command (executable-find "cmigemo"))
(defvar migemo-dictionary
  (locate-file "migemo-dict"
               '("/usr/share/cmigemo/utf-8"))) ; debian
(unless migemo-command
  (warn "migemo: `cmigemo' is unavailable! Please install it via `sudo apt install cmigemo' if possible."))
(use-package migemo
  :if (and migemo-command migemo-dictionary)
  :ensure t :defer nil :no-require t
  :functions migemo-init
  :config
  (set-variable 'migemo-options '("-q" "--emacs"))
  (set-variable 'migemo-coding-system 'utf-8-unix)
  (set-variable 'migemo-user-dictionary nil)
  (set-variable 'migemo-regex-dictionary nil)
  (load-library "migemo")
  (migemo-init))

;;;; mozc
;; require external package -> "emacs-mozc-bin"
(defvar mozc-emacs-helper (executable-find "mozc_emacs_helper"))
(unless mozc-emacs-helper
  (warn "mozc: `mozc_emacs_helmper' is unavailable! Please install it via `sudo apt install emacs-mozc-bin' if possible."))
(use-package mozc
  :if mozc-emacs-helper
  :ensure t :defer t
  :config
  (setq default-input-method "japanese-mozc"))

;;;; neotree
(use-package neotree
  :ensure t
  :bind ("C-q" . neotree-toggle)
  :config
  (setq neo-theme
        (if (display-graphic-p) 'nerd2 'arrow))
  (setq neo-show-hidden-files t)
  (setq neo-smart-open t))

;;;; nyan-mode
(use-package nyan-mode
  :ensure t
  :hook
  (after-init . nyan-mode)
  (nyan-mode . nyan-start-animation)
  :config
  (setq nyan-bar-length 10)
  (setq nyan-cat-face-number 4)
  (setq nyan-minimum-window-width 50))

;;;; org-bullets
;; https://github.com/sabof/org-bullets
(use-package org-bullets
  :ensure t
  :hook (org-mode . org-bullets-mode)
  :config
  ;;(setq org-bullets-bullet-list '("" "" "" "" "" "" "" "" "" ""))
  )

;;;; org-journal
(use-package org-journal
  :ensure t
  :if (version<= "9.1" (org-version))
  :bind ("C-c j" . org-journal-new-entry)
  :config
  (set-variable 'org-journal-dir "~/Dropbox/document/org/journal")
  (set-variable 'org-journal-date-format "%Y-%m-%d %A")
  ;;(setq org-journal-time-format "%R")
  (set-variable 'org-journal-file-format "%Y%m%d.org")
  (set-variable 'org-journal-find-file 'find-file)
  (setq org-extend-today-until '3)
  ;;; 折返しが起こったときの挙動の修正
  (add-hook 'visual-line-mode-hook
            '(lambda()
               (setq word-wrap nil))))

;;;; rainbow-delimiters
(use-package rainbow-delimiters
  :ensure t
  :hook (prog-mode . rainbow-delimiters-mode))

;;;; recentf-ext
(use-package recentf-ext :ensure t :defer nil)

;;;; redo+
(use-package redo+
  :pin manual :demand t
  :bind (("C-M-/" . redo)
         ("C-c /" . redo)
         ("C-M-_" . redo)))

;;;; smart-newline
(use-package smart-newline
  :ensure t :defer t
  :diminish smart-newline-mode
  :hook ((emacs-lisp-mode . smart-newline-mode)
         (python-mode . smart-newline-mode)))

;;;; smooth-scroll.el
(use-package smooth-scroll
  :ensure t
  :custom
  (smooth-scroll/vscroll-step-size 4)
  :config
  (smooth-scroll-mode t))

;;;; swap-buffers
(use-package swap-buffers
  :ensure t
  :bind (("C-M-o" . swap-buffers-keep-focus)
         ("C-c o" . swap-buffers-keep-focus)
         ("C-M-O" . swap-buffers)
         ("C-c O" . swap-buffers))
  :config
  (defun swap-buffers-keep-focus ()
    (interactive)
    (swap-buffers t)))

;;;; volatile-highlights
(use-package volatile-highlights
  :ensure t
  :diminish volatile-highlights-mode
  :hook (after-init . volatile-highlights-mode)
  :config
  ;;; custom-face
  (with-eval-after-load 'doom-dracula-theme
    (custom-set-faces
     '(vhl/default-face ((nil (:foreground "#FF3333" :background "#FFCDCD"))))
     )))

;;;; web-mode
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
  :config
  (setq web-mode-engines-alist
        '(("php" . "\\.phtml\\'")
          ("blade" . "\\.blade\\'"))))

;;;; which-key
(use-package which-key
  :ensure t
  :diminish which-key-mode
  :hook (after-init . which-key-mode))

;;;; winner
(use-package winner
  :ensure t
  :commands (winner-redo winner-undo)
  :config (winner-mode 1))

;;;; yaml-mode.el
;; docker-compose-modeでインストールされる
(use-package yaml-mode :disabled
  :ensure t
  :mode ("\\.ya?ml\\'"))



;; ++++++++++++++++++++++++++++++++++++++++++++++++++
;; Finalization
;; ++++++++++++++++++++++++++++++++++++++++++++++++++

;;;; Load time mesurement of init.el
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


;;(provide 'init)

;;; init.el ends here
