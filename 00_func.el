;; -*- encoding: utf-8-unix; -*-
;; * add-to-list-x
(defun add-to-list-x (LIST-VAR &rest REST)
"See also `add-to-list-l' `add-to-list-p'

\(add-to-list-x 'load-path
               init-dir
               (expand-file-name \"_misc/\" init-dir)
               )"
  (mapc (lambda(ELEMENT) (add-to-list LIST-VAR ELEMENT)) REST))

(defun add-to-list-l (LIST-VAR LIST)
"See also `add-to-list-x'"
  (apply 'add-to-list-x LIST-VAR LIST))

(defun add-to-list-p (LIST-VAR &optional BASE &rest REST)
"See also `add-to-list-x'"
  (mapc (lambda(ELEMENT) (add-to-list LIST-VAR (expand-file-name ELEMENT BASE))) REST))

;; * rq-x
(defun rq-x (action lst)
  "(rq-x 'require
        '(aaa bbb ccc ...))"
  (let ((action (cond ((eq action 0) 'require)(t action))))
    (mapcar (lambda(ext) (funcall action ext)) lst)))

(defmacro rqx (action &rest lst)
  "(rqx 0 aaa bbb ccc)"
;  (list 'rq-x `',action `',lst))
  `(rq-x ',action ',lst))

;; * define-key-s
(defun cons-list (lst)
  (if lst
      (cons
       (cons (car lst)(cadr lst))
       (cons-list (cddr lst)))))

(defun define-key-s (keymap key-defs &optional group)
  "(define-key-s 0 '(\"key\" def \"key\" def ...))
\(define-key-s 0 '(\"a\" \"b\" \"c\" ...) 'self-insert-command)
If keymap is 0, run as global-set-key
If keymap is 1, run as local-set-key
If keymap is xxx-mode-map, run as define-key xxx-mode-map
See also `def-key-s'."
  (let ((map (cond
              ((eq keymap 0) (current-global-map))
              ((eq keymap 1) (current-local-map))
              (t keymap)))
        (defs (if (null group)
                  (cons-list key-defs)
                (mapcar (lambda (k) (cons k group)) key-defs))))
    (mapc
     (lambda (d) (define-key map (eval `(kbd ,(car d))) (cdr d)))
     defs)))

(defmacro def-k-s (km &rest kd)
  "(def-key-s map \"key\" def \"key\" def ...)
See also `define-key-s'."
;  (list 'define-key-s km `',kd))
  `(define-key-s ,km ',kd))

(defun def-key-s (keymap &rest key-defs)
  ;; 对参数求值
  "(def-key-s map \"key\" 'def \"key\" 'def ...)
See also `define-key-s'."
  (define-key-s keymap key-defs))

;; * backward-kill-word-or-kill-region
(defun backward-kill-word-or-kill-region ()
  (interactive)
  (if mark-active
      (call-interactively 'kill-region)
    (call-interactively 'backward-kill-word)))

;; * outside
(defmacro outside (pre suf m)
  "up list N level, append PRE ahead and SUF behind, backward M char"
  `(lambda(&optional n)
     (interactive "P")
     (let ((x (if n (prefix-numeric-value n) 1))
           p)
       (up-list x)
       (setq p (point))
       (insert ,suf)
       (goto-char p)
       (setq p (backward-list))
       (while (member (char-to-string (get-byte (1- p)))
                      '("'" "`" "," "#" "@"))
         (setq p (1- p)))
       (goto-char p)
       (insert ,pre)
       (backward-char ,m)
       )))
;(def-key-s 0 "C-9" (outside "()" 1))

;; * shell-command-symbol-to-string
(defmacro shell-command-symbol-to-string (&rest s)
  `(shell-command-to-string
    (apply 'concat (mapcar
     (lambda(x)(concat (symbol-name x) " "))
     ',s))))
(defalias 'ss 'shell-command-symbol-to-string)

;; * temp file
(defun find-temp (&optional suffix)
  (interactive "sExtension: ")
  (let ((suf (if (and suffix (null (string= suffix "")))
                 (concat "." suffix))))
    (find-file
     (concat
      (make-temp-name
       (expand-file-name
        (format-time-string "%Y%m%d%H%M%S-" (current-time))
        work-dir))
      suf))
    (run-hooks 'find-temp-hook)))
(defun write-temp (filename &optional confirm)
  (interactive
   (list (if buffer-file-name
             (read-file-name "Write file: "
                             nil nil nil nil)
           (read-file-name "Write file: " default-directory
                           (expand-file-name
                            (file-name-nondirectory (buffer-name))
                            default-directory)
                           nil nil))
         (not current-prefix-arg)))
  (let ((fnm buffer-file-name))
    (write-file filename confirm)
    (if (file-exists-p fnm)
        (delete-file fnm))))
(add-hook 'find-temp-hook (lambda ()
                            (yank)))

;; * temp func
(defvar temp-func-list
  '(
    (mapc (lambda(x)(insert (prin1-to-string  x ) "\n")) (butlast temp-func-list))
    ))
(defun temp-func-add (&optional beg end)
  (interactive "r")
  (let* (b e 
           (x (if mark-active (read (buffer-substring-no-properties beg end))
                (up-list)(setq e (point))
                (backward-list)(setq b (point))
                (forward-list)
                (read (buffer-substring-no-properties b e)))))
    (if (null (equal x (car temp-func-list)))
        (push x temp-func-list)))
  (deactivate-mark))
(defun temp-func-call (&optional n)
  (interactive "p")
  (message
   (pp-to-string
    (let ((func (if (eq n 0)
                    (car (last temp-func-list))
                  (nth (1- n) temp-func-list))))
      (if (functionp func)
          (funcall func)
        (eval func))))))

;; * substring-buffer-name
(defun substring-buffer-name (m n &optional x)
  "使用 substring 截取文件名时，在 buffer-name 后面加几个字符，\
防止文件名过短引发错误。m n 参数同`substring'的 from to，可选参数\
 x 存在时截取带路径的文件名。"
  (substring (concat
              (if x
                  (buffer-file-name)
                (buffer-name))
              (make-string n ?*))
             m n))

;; * add-watchwords
(defun add-watchwords ()
  (font-lock-add-keywords
   nil '(("\\<\\(FIX\\|TODO\\|FIXME\\|HACK\\|REFACTOR\\|NOCOMMIT\\)"
          1 font-lock-warning-face t))))

;; * pretty symbol
(defun unicode-symbol (name)
  "Translate a symbolic name for a Unicode character -- e.g., LEFT-ARROW
 or GREATER-THAN into an actual Unicode character code. "
  (decode-char 'ucs (case name
                      (left-arrow 8592)
                      (up-arrow 8593)
                      (right-arrow 8594)
                      (down-arrow 8595)
                      (double-vertical-bar #X2551)
                      (equal #X003d)
                      (not-equal #X2260)
                      (identical #X2261)
                      (not-identical #X2262)
                      (less-than #X003c)
                      (greater-than #X003e)
                      (less-than-or-equal-to #X2264)
                      (greater-than-or-equal-to #X2265)
                      (logical-and #X2227)
                      (logical-or #X2228)
                      (logical-neg #X00AC)
                      ('nil #X2205)
                      (dagger #X2020)
                      (double-dagger #X2021)
                      (horizontal-ellipsis #X2026)
                      (reference-mark #X203B)
                      (double-exclamation #X203C)
                      (prime #X2032)
                      (double-prime #X2033)
                      (for-all #X2200)
                      (there-exists #X2203)
                      (element-of #X2208)
                      (square-root #X221A)
                      (squared #X00B2)
                      (cubed #X00B3)
                      (lambda #X03BB)
                      (alpha #X03B1)
                      (beta #X03B2)
                      (gamma #X03B3)
                      (delta #X03B4))))
(defun substitute-pattern-with-unicode (pattern symbol)
  "Add a font lock hook to replace the matched part of PATTERN with the
     Unicode symbol SYMBOL looked up with UNICODE-SYMBOL."
  (font-lock-add-keywords
   nil `((,pattern
          (0 (progn (compose-region (match-beginning 1) (match-end 1)
                                    ,(unicode-symbol symbol)
                                    'decompose-region)
                    nil))))))
(defun substitute-patterns-with-unicode (patterns)
  "Call SUBSTITUTE-PATTERN-WITH-UNICODE repeatedly."
  (mapcar #'(lambda (x)
              (substitute-pattern-with-unicode (car x)
                                               (cdr x)))
          patterns))
;; ** lisp symbol
(defun lisp-symbol ()
  (interactive)
  (substitute-patterns-with-unicode
   (cons-list '("(?\\(lambda\\>\\)" lambda
                ;; "\\<\\(lambda\\)\\>" lambda
                "\\(;;\\ \\)" reference-mark
                "\\(<-\\)" left-arrow
                "\\(->\\)" right-arrow
                ;; "\\(==\\)" identical
                ;; "\\(/=\\)" not-identical
                "\\(>=\\)" greater-than-or-equal-to
                "\\(<=\\)" less-than-or-equal-to
                ;; "\\(\\.\\.\\)" horizontal-ellipsis
                ))))

;; * add-exec-path
(defun add-exec-path (path)
  (interactive "Dexec-path: ")
  (setenv "PATH" (concat path ";" (getenv "PATH")))
  (push path exec-path))

;; * test
(defun mklst (n)
  "创建大小为 n 的字符串列表"
  (let* ((i n)(x nil))
    (while (> i 0)
      (setq x (cons (number-to-string i) x))
      (setq i (1- i)))
    x))

(defun eval-buffer-time ()
  ""
  (interactive)
  (let ((tm (float-time)))
    (eval-buffer)
    (message (number-to-string (- (float-time) tm)))))

(defmacro test-list (n &rest fn)
  "用大小为 n 的字符串列表，测试函数 fn (fn 最后一个参数为列表)"
  `(,@fn (mklst ,n)))

(defmacro test-times (n &rest body)
  "计算 body 运行 n 次所需时间"
  `(let ((tm ,n)(beg (float-time)))
     (while (> tm 0)
       (progn ,@body)
       (setq tm (1- tm)))
     (- (float-time) beg)
     ))

;(test-times 100 (test-list 9 define-key-s (current-local-map)))
