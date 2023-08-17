#lang racket
(provide (all-defined-out))
(require "match.rkt" "slt.rkt")
;<entry> ::= (<%entry> (<attr>*) <xml>*)
(define (%entry? x)
  (and (vector? x) (= (vector-length x) 9) (eq? (vector-ref x 0) '%entry)))
(define (make-%entry local? class id auto? section index present cite)
  (vector '%entry local? class id auto? section index present cite))
(define (%entry-local? %entry) (vector-ref %entry 1))
(define (%entry-class %entry) (vector-ref %entry 2))
(define (%entry-id %entry) (vector-ref %entry 3))
(define (%entry-auto? %entry) (vector-ref %entry 4))
(define (%entry-section %entry) (vector-ref %entry 5))
(define (%entry-index %entry) (vector-ref %entry 6))
(define (%entry-present %entry) (vector-ref %entry 7))
(define (%entry-cite %entry) (vector-ref %entry 8))
(define (set-%entry-local?! %entry local?) (vector-set! %entry 1 local?))
(define (set-%entry-class! %entry class) (vector-set! %entry 2 class))
(define (set-%entry-id! %entry id) (vector-set! %entry 3 id))
(define (set-%entry-auto?! %entry auto?) (vector-set! %entry 4 auto?))
(define (set-%entry-section! %entry section) (vector-set! %entry 5 section))
(define (set-%entry-index! %entry index) (vector-set! %entry 6 index))
(define (set-%entry-present! %entry present) (vector-set! %entry 7 present))
(define (set-%entry-cite! %entry cite) (vector-set! %entry 8 cite))
(define (build-%entry #:local? [local? #t] #:class [class #f] #:id [id #f] #:auto? [auto? #t]
                      #:section [section #f] #:index [index #f] #:present [present default-entry-present]
                      #:cite [cite default-entry-cite])
  (make-%entry local? class id auto? section index present cite))
(define (default-entry-present %entry attr* . xml*)
  (define class (%entry-class %entry))
  (define id (%entry-id %entry))
  `(div ,(attr*-set attr* 'class class 'id id) . ,xml*))
(define (default-entry-cite %entry)
  (define id (%entry-id %entry))
  (define href (string-append "#" id))
  `(a ((href ,href)) ,id))
;<heading> ::= (<%heading> (<attr>*) <xml>*)
(define (%heading? x)
  (and (vector? x) (= (vector-length x) 7) (eq? (vector-ref x 0) '%heading)))
(define (make-%heading level id auto? section present cite)
  (vector '%heading level id auto? section present cite))
(define (%heading-level %heading) (vector-ref %heading 1))
(define (%heading-id %heading) (vector-ref %heading 2))
(define (%heading-auto? %heading) (vector-ref %heading 3))
(define (%heading-section %heading) (vector-ref %heading 4))
(define (%heading-present %heading) (vector-ref %heading 5))
(define (%heading-cite %heading) (vector-ref %heading 6))
(define (set-%heading-level! %heading level) (vector-set! %heading 1 level))
(define (set-%heading-id! %heading id) (vector-set! %heading 2 id))
(define (set-%heading-auto?! %heading auto?) (vector-set! %heading 3 auto?))
(define (set-%heading-section! %heading section) (vector-set! %heading 4 section))
(define (set-%heading-present! %heading present) (vector-set! %heading 5 present))
(define (set-%heading-cite! %heading cite) (vector-set! %heading 6 cite))
(define (build-%heading #:level [level 1] #:id [id #f] #:auto? [auto? #t] #:section [section #f]
                        #:present [present default-heading-present]
                        #:cite [cite default-heading-cite])
  (make-%heading level id auto? section present cite))
(define (default-heading-present %heading attr* . xml*)
  (define level (%heading-level %heading))
  (define id (%heading-id %heading))
  (if (<= level 6)
      (let ((tag (string->symbol (format "h~s" level))))
        `(,tag ,(attr*-set attr* 'id id) . ,xml*))
      (let ((class (format "h~s" level)))
        `(div ,(attr*-set attr* 'class class 'id id) . ,xml*))))
(define (default-heading-cite %heading)
  (define id (%heading-id %heading))
  (define href (string-append "#" id))
  `(a ((href ,href)) ,id))
;henv auxiliaries
(define (make-compatible henv level)
  (define len (length henv))
  (define (aux henv i)
    (if (= i level)
        henv
        (aux (cons 0 henv) (add1 i))))
  (cond ((= len level) henv)
        ((> len level) (take-right henv level))
        (else (aux henv len))))
(define (henv-inc henv)
  (cons (add1 (car henv)) (cdr henv)))
(define (henv-next henv level)
  (henv-inc (make-compatible henv level)))
;g/lenv auxiliaries
(define (extend-g/lenv class index g/lenv)
  (cons (cons class (box index)) g/lenv))
(define (g/lenv-next g/lenv class)
  (define binding (assoc class g/lenv))
  (if binding
      (let* ((box0 (cdr binding))
             (nval (add1 (unbox box0))))
        (set-box! box0 nval)
        (values g/lenv nval))
      (values (extend-g/lenv class 1 g/lenv) 1)))
;pass0
(define (pass0 exp)
  (define citation-table '())
  (define (extend-table! id citation)
    (if (assoc id citation-table)
        (error 'automatic-numbering-pass0 "id conflict!")
        (set! citation-table
              (cons (cons id citation) citation-table))))
  (let iterate ((henv '(0)) (section #f) (genv '()) (lenv '()) (rest exp) (result '()))
    (if (null? rest)
        (cons citation-table (reverse result))
        (let ((current (car rest)) (rest (cdr rest)))
          (match current
            ((,tag ,attr* . ,xml*)
             (cond
               ((symbol? tag) (iterate henv section genv lenv rest (cons current result)))
               ((%heading? tag)
                (define level (%heading-level tag))
                (define id (%heading-id tag))
                (define auto? (%heading-auto? tag))
                (define present (%heading-present tag))
                (define cite (%heading-cite tag))
                (cond (auto? (define section (henv-next henv level))
                             (set-%heading-section! tag section)
                             (when id (extend-table! id (cite tag)))
                             (iterate section section genv '() rest
                                      (cons (apply present tag attr* xml*) result)))
                      (else (when id (extend-table! id (cite tag)))
                            (iterate henv (%heading-section tag) genv '() rest
                                     (cons (apply present tag attr* xml*) result)))))
               ((%entry? tag)
                (define local? (%entry-local? tag))
                (define class (%entry-class tag))
                (define id (%entry-id tag))
                (define auto? (%entry-auto? tag))
                (define present (%entry-present tag))
                (define cite (%entry-cite tag))
                (set-%entry-section! tag section)
                (cond (auto? (let-values (((g/lenv nval) (g/lenv-next (if local? lenv genv) class)))
                               (set-%entry-index! tag nval)
                               (when id (extend-table! id (cite tag)))
                               (if local?
                                   (iterate henv section genv g/lenv rest
                                            (cons (apply present tag attr* xml*) result))
                                   (iterate henv section g/lenv lenv rest
                                            (cons (apply present tag attr* xml*) result)))))
                      (else (when id (extend-table! id (cite tag)))
                            (iterate henv section genv lenv rest
                                     (cons (apply present tag attr* xml*) result)))))
               (else
                (iterate henv section genv lenv rest (cons current result)))))
            (,else (iterate henv section genv lenv rest (cons current result))))))))
;pass1
(define (Ref id) `(ref () ,id))
(define (pass1 exp)
  (define citation-table (car exp))
  (define (reify id)
    (cond ((assoc id citation-table) => cdr)
          (else (error 'pass1 "unknown id ~s" id))))
  (define Tr
    (T `((ref ,(lambda (ref empty id) (reify id))))))
  (define xml* (cdr exp))
  (map Tr xml*))
;automatic numbering
(define numbering-style*
  `((body
     *preorder*
     ,(lambda (tag attr* . xml*)
        `(,tag ,attr* . ,(pass1 (pass0 xml*)))))))
(define Tn
  (T numbering-style*))
;other utils
(define (fenced xml*)
  (add-between
   xml* '(", ") #:splice? #t
   #:before-first '("[") #:after-last '("]")))