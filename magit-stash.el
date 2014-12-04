;;; magit-stash.el --- stash support for Magit

;; Copyright (C) 2008-2014  The Magit Project Developers
;;
;; For a full list of contributors, see the AUTHORS.md file
;; at the top-level directory of this distribution and at
;; https://raw.github.com/magit/magit/master/AUTHORS.md

;; Author: Jonas Bernoulli <jonas@bernoul.li>
;; Maintainer: Jonas Bernoulli <jonas@bernoul.li>

;; Magit is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; Magit is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
;; or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
;; License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with Magit.  If not, see http://www.gnu.org/licenses.

;;; Commentary:

;; Support for Git stashes.

;;; Code:

(require 'magit)

;;; Commands

(magit-define-popup magit-stash-popup
  "Popup console for stash commands."
  'magit-popups
  :man-page "git-stash"
  :switches '((?u "Also save untracked files" "--include-untracked")
              (?a "Also save untracked and ignored files" "--all"))
  :actions  '((?z "Save"               magit-stash)
              (?Z "Snapshot"           magit-snapshot)
              (?p "Pop"                magit-stash-pop)
              (?i "Save index"         magit-stash-index)
              (?I "Snapshot index"     magit-snapshot-index)
              (?a "Apply"              magit-stash-apply)
              (?w "Save worktree"      magit-stash-worktree)
              (?W "Snapshot worktree"  magit-snapshot-worktree)
              (?l "List"               magit-stash-list)
              (?x "Save keeping index" magit-stash-keep-index)
              (?k "Drop"               magit-stash-drop)
              (?v "Show"               magit-stash-show)
              (?b "Branch"             magit-stash-branch))
  :default-action 'magit-stash
  :max-action-columns 3)

;;;###autoload
(defun magit-stash (message &optional include-untracked)
  "Create a stash of the index and working tree.
Untracked files are included according to popup arguments.
One prefix argument is equivalent to `--include-untracked'
while two prefix arguments are equivalent to `--all'."
  (interactive (magit-stash-read-args))
  (magit-stash-save message t t include-untracked t))

;;;###autoload
(defun magit-stash-index (message)
  "Create a stash of the index only.
Unstaged and untracked changes are not stashed."
  (interactive (list (magit-stash-read-message)))
  (error "This command is currently broken")
  (magit-stash-save message t nil nil t))

;;;###autoload
(defun magit-stash-worktree (message &optional include-untracked)
  "Create a stash of the working tree only.
Untracked files are included according to popup arguments.
One prefix argument is equivalent to `--include-untracked'
while two prefix arguments are equivalent to `--all'."
  (interactive (magit-stash-read-args))
  (error "This command is currently broken")
  (magit-stash-save message nil t include-untracked t))

;;;###autoload
(defun magit-stash-keep-index (message &optional include-untracked)
  "Create a stash of the index and working tree, keeping index intact.
Untracked files are included according to popup arguments.
One prefix argument is equivalent to `--include-untracked'
while two prefix arguments are equivalent to `--all'."
  (interactive (magit-stash-read-args))
  (magit-stash-save message t t include-untracked t 'index))

(defun magit-stash-read-args ()
  (list (magit-stash-read-message)
        (magit-stash-read-untracked)))

(defun magit-stash-read-untracked ()
  (let ((prefix (prefix-numeric-value current-prefix-arg))
        (args   (magit-stash-arguments)))
    (cond ((or (= prefix 16) (member "--all" args)) 'all)
          ((or (= prefix  4) (member "--include-untracked" args)) t))))

(defun magit-stash-read-message ()
  (let* ((default (format "On %s: "
                          (or (magit-get-current-branch) "(no branch)")))
         (input (magit-read-string "Stash message" default)))
    (if (equal input default)
        (concat default (magit-rev-format "%h %s"))
      input)))

;;;###autoload
(defun magit-snapshot (&optional include-untracked)
  "Create a snapshot of the index and working tree.
Untracked files are included according to popup arguments.
One prefix argument is equivalent to `--include-untracked'
while two prefix arguments are equivalent to `--all'."
  (interactive (magit-snapshot-read-args))
  (magit-snapshot-save t t include-untracked t))

;;;###autoload
(defun magit-snapshot-index ()
  "Create a snapshot of the index only.
Unstaged and untracked changes are not stashed."
  (interactive)
  (magit-snapshot-save t nil nil t))

;;;###autoload
(defun magit-snapshot-worktree (&optional include-untracked)
  "Create a snapshot of the working tree only.
Untracked files are included according to popup arguments.
One prefix argument is equivalent to `--include-untracked'
while two prefix arguments are equivalent to `--all'."
  (interactive (magit-snapshot-read-args))
  (magit-snapshot-save nil t include-untracked t))

(defun magit-snapshot-read-args ()
  (list (magit-stash-read-untracked)))

(defun magit-snapshot-save (index worktree untracked &optional refresh)
  (magit-stash-save (concat "WIP on " (magit-stash-summary))
                    index worktree untracked refresh t))

(defun magit-stash-apply (stash)
  "Apply a stash to the working tree.
Try to preserve the stash index.  If that fails because there
are staged changes, apply without preserving the stash index."
  (interactive (list (magit-read-stash "Apply stash" t)))
  (if (= (magit-call-git "stash" "apply" "--index" stash) 0)
      (magit-refresh)
    (magit-run-git "stash" "apply" stash)))

(defun magit-stash-pop (stash)
  "Apply a stash to the working tree and remove it from stash list.
Try to preserve the stash index.  If that fails because there
are staged changes, apply without preserving the stash index
and forgo removing the stash."
  (interactive (list (magit-read-stash "Apply pop" t)))
  (if (= (magit-call-git "stash" "apply" "--index" stash) 0)
      (magit-stash-drop stash)
    (magit-run-git "stash" "apply" stash)))

(defun magit-stash-drop (stash)
  "Remove a stash from the stash list.
When the region is active offer to drop all contained stashes."
  (interactive (list (--if-let (magit-region-values 'stash)
                         (magit-confirm t nil "Drop %i stashes" it)
                       (magit-read-stash "Drop stash"))))
  (if (listp stash)
      (mapc 'magit-stash-drop (nreverse stash))
    (magit-call-git "reflog" "delete" "--updateref" "--rewrite" stash)
    (-when-let (ref (and (string-match "\\(.+\\)@{[0-9]+}$" stash)
                         (match-string 1 stash)))
      (unless (string-match "^refs/" ref)
        (setq ref (concat "refs/" ref)))
      (unless (magit-rev-verify (concat ref "@{0}"))
        (magit-run-git "update-ref" "-d" ref)))
    (magit-refresh)))

(defun magit-stash-clear (ref)
  "Remove all stashes saved in REF's reflog by deleting REF."
  (interactive
   (let ((ref (or (magit-section-when 'stashes) "refs/stash")))
     (if (magit-confirm t (format "Drop all stashes in %s" ref))
         (list ref)
       (user-error "Abort"))))
  (magit-run-git "update-ref" "-d" ref))

(defun magit-stash-branch (stash branch)
  "Create and checkout a new BRANCH from STASH."
  (interactive (list (magit-read-stash  "Branch stash" t)
                     (magit-read-string "Branch name")))
  (magit-run-git "stash" "branch" branch stash))

;;; Plumbing

(defun magit-stash-save (message index worktree untracked
                                 &optional refresh keep noerror ref)
  (if (or (and index     (magit-staged-files t))
          (and worktree  (magit-modified-files t))
          (and untracked (magit-untracked-files (eq untracked 'all))))
      (progn
        (magit-stash-store message (or ref "refs/stash")
                           (magit-stash-create message index worktree untracked))
        (unless (and keep (not (eq keep 'index)))
          (when untracked
            (magit-call-git "clean" "-f" (and (eq untracked 'all) "-x")))
          (if keep
              (magit-call-git "checkout" "--" ".")
            (magit-call-git "reset" "--hard" "HEAD")))
        (when refresh
          (magit-refresh)))
    (unless noerror
      (user-error "No %s changes to save" (cond ((not index)  "unstaged")
                                                ((not worktree) "staged")
                                                (t "local"))))))

(defun magit-stash-store (message ref commit)
  (magit-reflog-enable ref t)
  (unless (magit-git-success "update-ref" "-m" message ref commit
                             (or (magit-rev-verify ref) ""))
    (error "Cannot update %s with %s" ref commit)))

(defun magit-stash-create (message index worktree untracked)
  (unless (magit-rev-parse "--verify" "HEAD")
    (error "You do not have the initial commit yet"))
  (let ((default-directory (magit-get-top-dir))
        (summary (magit-stash-summary)))
    (or (setq index
              (magit-commit-tree (concat "index on " summary)
                                 (unless index (magit-rev-parse "HEAD^{tree}"))
                                 "HEAD"))
        (error "Cannot save the current index state"))
    (and untracked
         (setq untracked (magit-untracked-files (eq untracked 'all)))
         (setq untracked (magit-with-temp-index nil
                           (or (and (magit-update-files untracked)
                                    (magit-commit-tree
                                     (concat "untracked files on " summary)))
                               (error "Cannot save the untracked files")))))
    (magit-with-temp-index (if worktree "HEAD" index)
      (when worktree
        (or (magit-update-files (magit-git-lines "diff" "--name-only" "HEAD"))
            (error "Cannot save the current worktree state")))
      (or (magit-commit-tree message nil "HEAD" index untracked)
          (error "Cannot save the current worktree state")))))

(defun magit-stash-summary ()
  (concat (or (magit-get-current-branch) "(no branch)")
          ": " (magit-rev-format "%h %s")))

;;; Sections

(defvar magit-stashes-section-map
  (let ((map (make-sparse-keymap)))
    (define-key map "k"  'magit-stash-clear)
    map)
  "Keymap for `stashes' section.")

(defvar magit-stash-section-map
  (let ((map (make-sparse-keymap)))
    (define-key map "\r" 'magit-stash-show)
    (define-key map "a"  'magit-stash-apply)
    (define-key map "A"  'magit-stash-pop)
    (define-key map "k"  'magit-stash-drop)
    map)
  "Keymap for `stash' sections.")

(magit-define-section-jumper stashes "Stashes" "refs/stash")

(cl-defun magit-insert-stashes (&optional (ref   "refs/stash")
                                          (heading "Stashes:"))
  (when (magit-rev-verify ref)
    (magit-insert-section (stashes ref)
      (magit-insert-heading heading)
      (magit-git-wash (apply-partially 'magit-log-wash-log 'stash)
        "-c" "log.date=default" ; kludge for <1.7.10.3, see #1427
        "reflog" "--format=%gd %at %gs" ref))))

;;; List Stashes

(defcustom magit-stashes-buffer-name-format "*magit-stashes: %a*"
  "Name format for buffers used to list stashes.

The following `format'-like specs are supported:
%a the absolute filename of the repository toplevel.
%b the basename of the repository toplevel."
  :package-version '(magit . "2.1.0")
  :group 'magit-modes
  :type 'string)

(defun magit-stash-list ()
  "List all stashes in a buffer."
  (interactive)
  (magit-mode-setup magit-stashes-buffer-name-format nil
                    #'magit-stashes-mode
                    #'magit-stashes-refresh-buffer))

(define-derived-mode magit-stashes-mode magit-reflog-mode "Magit Stashes"
  "Mode for looking at lists of stashes."
  :group 'magit)

(cl-defun magit-stashes-refresh-buffer (&optional (ref   "refs/stash")
                                                  (heading "Stashes:"))
  (magit-insert-section (stashesbuf)
    (magit-insert-heading heading)
    (magit-git-wash (apply-partially 'magit-log-wash-log 'stash)
      "-c" "log.date=default" ; kludge for <1.7.10.3, see #1427
      "reflog" "--format=%gd %at %gs" ref)))

;;; Show Stash

(defcustom magit-stash-sections-hook
  '(magit-insert-stash-message
    magit-insert-stash-index
    magit-insert-stash-worktree
    magit-insert-stash-untracked)
  "Hook run to insert sections into stash buffers."
  :package-version '(magit . "2.1.0")
  :group 'magit-modes
  :type 'hook)

(defcustom magit-stash-buffer-name-format "*magit-stash: %a*"
  "Name format for buffers used to show stash diffs.

The following `format'-like specs are supported:
%a the absolute filename of the repository toplevel.
%b the basename of the repository toplevel."
  :package-version '(magit . "2.1.0")
  :group 'magit-modes
  :type 'string)

(defun magit-stash-show (stash &optional noselect args)
  "Show all diffs of a stash in a buffer."
  (interactive (list (or (and (not current-prefix-arg)
                              (magit-stash-at-point))
                         (magit-read-stash "Show stash"))
                     nil (magit-diff-arguments)))
  (magit-mode-setup magit-stash-buffer-name-format
                    (if noselect 'display-buffer 'pop-to-buffer)
                    #'magit-stash-mode
                    #'magit-stash-refresh-buffer stash args))

(define-derived-mode magit-stash-mode magit-diff-mode "Magit Stash"
  "Mode for looking at individual stashes."
  :group 'magit)

(defun magit-stash-refresh-buffer (stash args)
  (magit-insert-section (stash)
    (run-hooks 'magit-stash-sections-hook)))

(defun magit-insert-stash-message ()
  (let ((stash (car magit-refresh-args)))
    (magit-insert-section (stash-message)
      (magit-insert
       (concat (propertize (capitalize stash) 'face 'magit-section-heading) "\s"
               (magit-rev-format "%s" stash) "\n")))))

(defmacro magit-stash-insert-section (subtype format &optional files)
  `(let ((stash (car magit-refresh-args)))
     (magit-insert-section (,(intern (format "stashed-%s" subtype)))
       (magit-insert-heading (format "%s %s:" (capitalize stash) ',subtype))
       (magit-git-wash #'magit-diff-wash-diffs
         "diff" (cdr magit-refresh-args) "--no-prefix"
         (format ,format stash stash) "--" ,files))))

(defun magit-insert-stash-index ()
  (magit-stash-insert-section index "%s^..%s^2"))

(defun magit-insert-stash-worktree ()
  (magit-stash-insert-section worktree "%s^2..%s"))

(defun magit-insert-stash-untracked ()
  (-when-let (files (magit-git-lines "ls-tree" "--name-only" "--full-tree"
                                     (concat (car magit-refresh-args) "^3")))
      (magit-stash-insert-section untracked "%s^..%s^3" files)))

;;; magit-stash.el ends soon
(provide 'magit-stash)
;; Local Variables:
;; indent-tabs-mode: nil
;; End:
;;; magit-stash.el ends here
