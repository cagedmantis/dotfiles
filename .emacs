;; Carlos Amedee emacs config
;; Date Stamp

(tool-bar-mode nil)                            ; No toolbar
(set-scroll-bar-mode 'right)                   ; Scrollbar on the right
(setq inhibit-startup-message t)               ; No message at startup
(setq shell-file-name "/bin/bash")             ; Set Shell for M-| command
(setq sentence-end-double-space nil)           ; Sentences end with one space
(setq-default indent-tabs-mode nil)            ; Use spaces instead of tabs
(column-number-mode t)                         ; Show column number in mode-line
(global-font-lock-mode 1)                      ; Color enabled
(global-font-lock-mode t)		       ; fonts are automatically highlighted
(setq visible-bell t)                          ; No beep when reporting errors
(defalias 'yes-or-no-p 'y-or-n-p)              ; y/n instead of yes/no
(speedbar t)                                   ; Quick file access with bar
(setq ispell-dictionary "english")             ; Set ispell dictionary
(setq make-backup-files nil)                   ; No backup files ~


;; yasnippet
(add-to-list 'load-path
	     "~/.emacs.d/plugins/yasnippet-0.6.1c")
(require 'yasnippet) ;; not yasnippet-bundle
(yas/initialize)
(yas/load-directory "~/.emacs.d/plugins/yasnippet-0.6.1c/snippets")

;; Color Theme
(add-to-list 'load-path
	     "~/.emacs.d/plugins/color-theme-6.6.0")
(require 'color-theme)
(color-theme-initialize)
(color-theme-arjen)


(setq visible-bell t)                          ; No beep when reporting errors
(defalias 'yes-or-no-p 'y-or-n-p)              ; y/n instead of yes/no
(speedbar t)                                   ; Quick file access with bar
(setq ispell-dictionary "english")             ; Set ispell dictionary
(setq make-backup-files nil)                   ; No backup files ~


;; yasnippet
(add-to-list 'load-path
	     "~/.emacs.d/plugins/yasnippet-0.6.1c")
(require 'yasnippet) ;; not yasnippet-bundle
(yas/initialize)
(yas/load-directory "~/.emacs.d/plugins/yasnippet-0.6.1c/snippets")

;; Color Theme
(add-to-list 'load-path
	     "~/.emacs.d/plugins/color-theme-6.6.0")
(require 'color-theme)
(color-theme-initialize)
(color-theme-arjen)

;;;;;;;;;;;;;;;;;;;;
;; set up unicode
(prefer-coding-system       'utf-8)
(set-default-coding-systems 'utf-8)
(set-terminal-coding-system 'utf-8)
;;(set-keyboard-coding-system 'utf-8)
;; This from a japanese individual.  I hope it works.
(setq default-buffer-file-coding-system 'utf-8)
;; From Emacs wiki
(setq x-select-request-type '(UTF8_STRING COMPOUND_TEXT TEXT STRING))
;; MS Windows clipboard is UTF-16LE 
(set-clipboard-coding-system 'utf-16le-dos)

;;; This was installed by package-install.el.
;;; This provides support for the package system and
;;; interfacing with ELPA, the package archive.
;;; Move this code earlier if you want to reference
;;; packages in your .emacs.
(when
    (load
     (expand-file-name "~/.emacs.d/elpa/package.el"))
  (package-initialize))

;; Enable proper color interpretation in emacs shell mode
(autoload 'ansi-color-for-comint-mode-on "ansi-color" nil t)
(add-hook 'shell-mode-hook 'ansi-color-for-comint-mode-on)


(require 'org-install)
(add-to-list 'auto-mode-alist '("\\.org$" . org-mode))
(define-key global-map "\C-cl" 'org-store-link)
(define-key global-map "\C-ca" 'org-agenda)
(setq org-log-done t)