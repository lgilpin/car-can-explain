;;; ------------------------------------------------------------------
;;; Copyright 2016 Alexey Radul and Gerald Jay Sussman
;;; ------------------------------------------------------------------
;;; This file is part of New Propagator Prototype.  It is derived from
;;; the Artistic Propagator Prototype previously developed by Alexey
;;; Radul and Gerald Jay Sussman.
;;; 
;;; New Propagator Prototype is free software; you can redistribute it
;;; and/or modify it under the terms of the GNU General Public License
;;; as published by the Free Software Foundation, either version 3 of
;;; the License, or (at your option) any later version.
;;; 
;;; New Propagator Prototype is distributed in the hope that it will
;;; be useful, but WITHOUT ANY WARRANTY; without even the implied
;;; warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
;;; See the GNU General Public License for more details.
;;; 
;;; You should have received a copy of the GNU General Public License
;;; along with New Artistic Propagator Prototype.  If not, see
;;; <http://www.gnu.org/licenses/>.
;;; ------------------------------------------------------------------

(declare (usual-integrations make-cell))

(define-structure
 (v&s (named 'supported) (type list)
      (constructor %supported (value support #!optional reasons))
      (print-procedure #f))
 value support (reasons (list *my-parent*)))

(define (supported value support #!optional reasons)
  (if (and (pair? value)
           (not (or (nothingness? value)
                    (eq? value the-contradiction)
                    (boolean? value)
                    (interval? value)
                    (abstract-number? value))))
      (bkpt "value"))
  (if (not (every (lambda (p) 
                    (or (symbol? p)
                        (hypothetical? p)))
                  support))
      (bkpt "bad support"))
  (if (default-object? reasons)
      (%supported value support)
      (%supported value support reasons)))

;;; Should be generic.
(define (implies-values? v1 v2)
  (cond ((nothingness? v1) #f)
        ((nothingness? v2) #t)
        ((contradiction? v1) #t)
        ((contradiction? v2) #f)
        ((and (boolean? v1) (boolean? v2))
         (eq? v1 v2))
        (;; v1 implies v2 iff v1=v2.
         (and (number? v1) (number? v2))
         (default-equal? v1 v2))
        #| ;; Makes multi-plunk-test fail quadratically!
        ((and (number? v1) (abstract-number? v2))
         #t)
        ((and (number? v2) (abstract-number? v1))
         #f)
        |#
        (;; v1 implies v2 iff v1=v2.
         (or (abstract-number? v1) (abstract-number? v2))
         (equivalent-values? v1 v2))
        ((and (interval? v1) (interval? v2))
         (subinterval? v1 v2))
        ((and (interval? v1) (number? v2))
         #f)
        ((and (number? v1) (interval? v2))
         (within-interval? v1 v2))
        (else
         (error "Implies? is confused" v1 v2))))

(define (merge:flat-v&ss v&s1 v&s2)
  (if (or (not (all-premises-in? (v&s-support v&s2)))
          (not (all-premises-in? (v&s-support v&s1))))
      (make-tms (list v&s1 v&s2))
      (let* ((v&s1-value (v&s-value v&s1))
             (v&s2-value (v&s-value v&s2))
             (merge-value 
              (force-v&s-to-value
               (merge v&s1-value v&s2-value))))
        (cond ((equivalent-values? merge-value v&s1-value)
               (if (more-informative-support? v&s2 v&s1)
                   v&s2
                   v&s1))
              ((equivalent-values? merge-value v&s2-value)
               ;; New information overrides old information
               v&s2)
              (else
               ;; Interesting merge, need both provenances
               (supported merge-value
                          (merge-supports v&s1 v&s2)
                          (merge-reasons v&s1 v&s2)))))))

(define (force-v&s-to-value x)
  (if (v&s? x) (v&s-value x) x))

(define (flat? thing)
  (or (interval? thing)
      (number? thing)
      (boolean? thing)))

(define (flat-v&s? x)
  (and (v&s? x) (flat? (v&s-value x))))

(assign-operation 'merge merge:flat-v&ss flat-v&s? flat-v&s?)

(define (merge:flat-v&s-flat v f)
  (merge:flat-v&ss v (->v&s f)))
(define (merge:flat-flat-v&s f v)
  (merge:flat-v&ss (->v&s f) v))

(assign-operation 'merge merge:flat-v&s-flat flat-v&s? flat?)
(assign-operation 'merge merge:flat-flat-v&s flat? flat-v&s?)

(define (contradictory-v&s? x)
  (and (v&s? x) (contradictory? (v&s-value x))))

(define (merge-contradiction x y)
  (supported the-contradiction
              (merge-supports x y)
              (merge-reasons x y)))

(assign-operation 'merge merge-contradiction contradictory-v&s? v&s?)

(assign-operation 'merge merge-contradiction v&s? contradictory-v&s?)


(define equivalent-values? generic-=)

(define (more-informative-support? v&s1 v&s2)
  (and (not (lset= equal? (v&s-support v&s1) (v&s-support v&s2)))
       (lset<= equal? (v&s-support v&s1) (v&s-support v&s2))))

(define (merge-supports . v&ss)
  (apply lset-union equal? (map v&s-support v&ss)))

(define (merge-reasons . v&ss)
  (apply lset-union equal? (map v&s-reasons v&ss)))


(assign-operation
 'true? (lambda (v&s) (generic-true? (v&s-value v&s))) v&s?)

(define (v&s-contradictory? v&s)
  (contradictory? (v&s-value v&s)))

(assign-operation 'contradictory? v&s-contradictory? v&s?)


(define (v&s-nothingness? v&s)
  (nothingness? (v&s-value v&s)))

(assign-operation 'nothingness? v&s-nothingness? v&s?)


(define (v&s-abstract? v&s)
  (abstract? (v&s-value v&s)))

(assign-operation 'abstract? v&s-abstract? v&s?)

(define ((v&s-unpacking f) . args)
  (v&s-unpacker f args))

(define ((v&s-unpacking-and-coercing f) . args)
  (v&s-unpacker f (map ->v&s args)))

(define (v&s-unpacker f args)
  (let ((v (apply f (map v&s-value args))))
    (supported v
               (apply merge-supports args)
               (list *my-parent*))))

(define (->v&s thing #!optional reasons)
  (if (v&s? thing)
      (if (default-object? reasons)
          thing
          (let ((new-reasons
                 (lset-union equal?
                             (v&s-reasons thing)
                             reasons)))
            (supported (v&s-value thing)
                       (v&s-support thing)
                       new-reasons)))
      (if (default-object? reasons)
          (supported thing '() (list *my-parent*))
          (supported thing '() reasons))))

;;; Primitive generic operators are known here--ugh!

(for-each
 (lambda (name underlying-operation)
   (assign-operation name
                     (v&s-unpacking underlying-operation)
                     v&s? v&s?)
   (assign-operation name
                     (v&s-unpacking-and-coercing
                      underlying-operation)
                     v&s? flat?)
   (assign-operation name
                     (v&s-unpacking-and-coercing 
                      underlying-operation)
                     flat? v&s?))
 '(+ - * /
   generic-= generic-< generic-> generic-<= generic->=
   and or dna ro)
 (list ;; generic-+ generic-- generic-* generic-/
       generic:+ generic:- generic:* generic:/
       generic-= generic-< generic-> generic-<= generic->=
       generic-and generic-or generic-dna generic-ro))
 
(for-each
 (lambda (name underlying-operation)
   (assign-operation name
                     (v&s-unpacking underlying-operation)
                     v&s?))
 '(abs square sqrt generic-sign negate invert exp 
   log not imp pmi identity)
 (list ;; generic-abs generic-square generic-sqrt
       g:abs g:square g:sqrt generic-sign g:negate g:invert g:exp 
       g:log generic-not generic-imp generic-pmi generic-identity))
