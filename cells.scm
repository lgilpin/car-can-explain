;;; ------------------------------------------------------------------
;;; Copyright 2008--2016 Alexey Radul and Gerald Jay Sussman
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

;;;; Cells
;;;  a cell is represented by a message-acceptor.
;;;  a cell has a parent, of which it is a part.
;;;  there is a top-level parent of the sytem.  the fluid
;;;  variable *my-parent* is defined in scheduler.scm

(define *stop-on-contradiction* #f)

(define (make-cell #!optional name)
  (let ((neighbors '()) (content nothing) (probe #f))
    (define (new-neighbor! new-neighbor)
      (if (not (memq new-neighbor neighbors))
          (begin (set! neighbors (cons new-neighbor neighbors))
                 (alert-propagators new-neighbor))))
    (define (add-content increment source)  
      (let ((answer (merge content (add-source increment source))))
      (if probe (probe (me 'name) content increment source answer))
        (cond ((equivalent? answer content)
	       'ok)
              ((contradictory? answer)
               (if *stop-on-contradiction*
                   (bkpt "contradiction in cell" (me 'name)))
               (set! content answer)
               (note-contradiction! answer))
              (else
               (set! content answer)
               (alert-propagators neighbors)))))
    (define (note-contradiction! answer)
      (let ((vs (strongest-consequence answer)))
        (process-nogood! (v&s-support vs)
                         (v&s-reasons vs)
                         me)))
    (define (me message)
      (case message
        ((add-content) add-content)
        ((content) content)
        ((new-neighbor!) new-neighbor!)
	((neighbors) neighbors)
        ((name) name)
        ((set-name!) (lambda (new)
                       (set! name new)
                       (eq-put! me 'name name)))
        ((probe!) (lambda (new-probe)
                    (set! probe new-probe)))
        (else (error "Unknown message" message) me)))
    (if (default-object? name)
	((me 'set-name!) me)
	((me 'set-name!) name)) 
    (eq-put! me 'cell #t)               ;I am a cell!
    (eq-put! me 'parent *my-parent*)
    (eq-adjoin! *my-parent* 'children me)
    me))

(define (cell? thing)
  (eq-get thing 'cell))

(define (cell-name cell)
  (cell 'name))

(define (set-cell-name! cell name)
  ((cell 'set-name!) name))

(define (new-neighbor! cell neighbor)
  ((cell 'new-neighbor!) neighbor))

(define (neighbors cell)
  (cell 'neighbors))

(define add-content-wallp #f)

(define (add-content cell increment #!optional source)
  (if (default-object? source) (set! source *my-parent*))
  (if add-content-wallp
      (write-line `(cell-assigned
                    ,(name cell)
                    ,increment
                    ,(name source))))
  ((cell 'add-content) increment source))

(define (content cell)
  (cell 'content))

(define (add-source thing source)
  (cond ((v&s? thing)
	 (if (member source (v&s-reasons thing))
	     thing
	     (let ((new-reasons
		    (lset-union equal?
				(v&s-reasons thing)
				(list source))))
	       (supported (v&s-value thing)
			  (v&s-support thing)
			  new-reasons))))
        ((tms? thing)
         (make-tms 
          (map (lambda (vs)
                 (add-source vs source))
               (tms-values thing))))
        (else
         (supported thing 
                    '() 
                    (list source)))))

(define nothing
  (list '*the-nothing*))

(define (nothing? thing)
  (eq? thing nothing))

(define nothingness? 
  (make-generic-operator 1
                         'nothingness? 
                         nothing?))

(define the-contradiction
  (list 'contradiction))

(define (contradiction? thing)
  (eq? thing the-contradiction))

(define merge
  (make-generic-operator 2 'merge
   (lambda (content increment)
     (if (default-equal? content increment)
         content
         the-contradiction))))

;;; These should have priority.  They don't!
(assign-operation 'merge
 (lambda (content increment) content)
 any? nothingness?)

(assign-operation 'merge
 (lambda (content increment) increment)
 nothingness? any?)

(define contradictory?
  (make-generic-operator 1
                         'contradictory?
                         contradiction?))


(define abstract?
  (make-generic-operator 1
                         'abstract?
                         abstract-number?))

(define (equivalent? x y)
  (or (eq? x y)
      (equivalent-tmss? x y)))