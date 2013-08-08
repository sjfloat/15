
So, I was at Cracker Barrel, where they have this game with fifteen holes and
fourteen golf tees.  I played around with it for a while, and was able to come
up with a way to end up with two pegs.

I was wondering if there actually was a solution to the game.  I started
thinking about it.

Later that day, in a curious turn of hotel selection luck and laziness, we
ended up at a different Cracker Barrel.  I played the game some more and ended
up with one peg.  So there is a solution.

I enjoy writing solvers for games like this.  So here's what I was thinking:

First, there are fifteen holes, each of which can contain a peg or not.  If we
represent each hole in the board by a bit in a number, we can number the states.
For example, a state with a peg in holes 3, 11, and 14 would be 18440 (a number
with bits 3, 11, and 14 set is 2^3 + 2^11 + 2^14).

The ability to number states is really useful for this kind of problem.  It
allows us to give an upper bound to the number of possible states that can
help us design a solution.  In this case, we have the upper bound of 2^15,
which is 32768.  There is at least one state which can't be reached–the state
with no pegs.  There's clearly other states which can't be reached: for
example, only the starting state has one peg missing–since we need to remove
a peg for each move, there are no other states with one peg missing; however,
since we have every possible bit combination of fifteen bits between zero
and 32,768, we have fifteen different numbered states which have one bit
missing.  Also think of this: there's only two possible moves at the beginning
of the game, so there are only two possible boards with two pegs missing,
but we have (15 choose 2) numbers.

This is fine.  Figuring out that we can encode the states like this serves
two purposes: 1) We know that we can fit all the states in memory.  2) We
know that we can make an array of size 32,768 if we want to keep track of
some kind of information about each state (like whether we've seen it
before when searching, or how many steps it takes to reach it, or from
which previous step we reached it).

```lisp
(defvar *start-state* #*011111111111111)
```

And we need to know when we've reached a goal state, which is any state
with just one peg:

```lisp
(defun end-state-p (state)
  (= 1 (reduce #'+ state)))
```

This function sums all the bits and checks if the sum is `1`, indicating
that just one bit is set.  I wrote it and tested it in the SBCL REPL.

The next thing we need to figure out is how to tell which holes are adjacent
to other holes.  First, to choose a numbering scheme.  The simplest thing
seems to be this:

               0
	     1   2
	   3   4   5
	 6   7   8   9
      10  11  12  13  14


My first thought is that I can keep a logic table says
things like:

* If hole 0 is filled and hole 2 is filled and hole 5 is empty, we can fill
  hole five and empty holes zero and two.
* If hole 0 is filled and hole 1 is filled and hole 3 is empty, we can fill
  hole three and empty holes zero and one.

And so forth, with one entry for every three consecutve holes.  I think
there would be thirty-six entries this way (each row of five has six–three
in each direction, each row of four holes has four consecutive threes,
each row of three has two consecutive threes.  There are three of each
of those kinds of rows.)

Ugh.

But then I remember that there's a way for representing a complete binary
tree as an array.  A complete binary tree is one in which every node which is
not on the bottom level has both a right branch and a left branch.

In this scheme, we can move from a node to its left child by multiplying by
two and we can move to a node's right child by multiplying by two and adding
one.

I look at my diagram and see this doesn't work since we expect hole 4 to be
reachable as the right child of 1 _and_ the left child of 2, which is
contrary to the complete binary tree notion.  I wonder if I can play with
the math a little bit to get it to work for our case and have no luck.
(I notice different numbers need to be added for each layer.)

Ugh.

So then I think the simplest thing I can do is to keep track of sequences
of consecutive holes.  This seems straightforward in Lisp:

```lisp
(defvar *sequences* '((0 2 5 9 14) ; Moving down and right
                      (1 4 8 13)
		      (3 7 12)
		      (0 1 3 6 10) ; Moving down and left
		      (2 4 7 11)
		      (5 8 12)
		      (3 4 5)      ; Moving left-to-right
		      (6 7 8 9)
		      (10 11 12 13 14)))
```

I've removed entries for rows with fewer than three consecutive slots, since
we can't jump a peg with fewer than three slots and I can't think of another
use for the information.

Now that we know how holes connect to each other, we need to figure out how
to compute, given a starting state, all the states which are reachable by
making one valid move.

```lisp
(defun next-states (state)
  (let ((result ()))
    (loop for sequence in *sequences*
    	  do (dolist (rest-of sequence)
	       (if (and (>= (length rest-of) 3)

...
```

So I took a break, and came back to this a while later.  When I did, I noticed
a bunch of simpler steps I could take, so let's back up a little bit.  First,
let's figure out how to reverse a bit in a Common Lisp bit array:

```lisp
(defun reverse-bit (state bit)
  (setf (aref state bit) (lognot (aref state bit))))
```
        
And test in the REPL.  It turns out this is wrong, as LOGNOT does not return
1 for 0 and 0 for 1.  But, in looking at the documentation, I found LOGCOUNT,
which I imagine counts the bits in a number.  I tested a few cases:

```lisp
(logcount 22) => 3
(logcount 1) => 1
(logcount 2) => 1
```

And then used SBCL's built-in DESCRIBE to get the documentation of LOGCOUNT,
which confirmed it will count the number of set bits (if the integer is
positive).  If the integer is negative, it counts the number of zero bits.
Weird, but OK.

So I'm thinking, "Cool!  I can use LOGCOUNT in my END-STATE-P!"  Alas, no,
it's not simpler: LOGCOUNT takes an integer, while END-STATE-P operates on a
bit vector.  I still haven't figured out how to convert between integers and
bit vectors, but it seems to be more operations just to use LOGCOUNT anyhow.

I add an entry for LOGCOUNT to my local Anki deck for Common Lisp anyhow.

In any case, we can use LOGXOR to flip the low bit, changing 0 to 1 and 1
to 0, fixing our REVERSE-BIT:

```lisp
(defun reverse-bit (state bit)
  (setf (aref state bit) (logxor 1 (aref state bit))))
```

Try it in the REPL and, oops, we don't want to mutate STATE, we want a modified
copy.

```lisp
(defun reverse-bit (state bit)
  (let ((copy (copy-seq state)))
    (setf (aref copy bit) (logxor 1 (aref copy bit)))
    copy))
```

Test this in the REPL, and yay!  Success!

So I'm thinking about this function, and I'm not sure I like it.  Why?  Well,
when I was thinking about how moves work, they reverse three bits at a time.
A move can only be made when the spot to which you jump is empty and the
other two are full, this means that all three holes are "flipped":  The peg
which does the jumping is turned from full to empty, the peg being jumped
turned from full to empty, and the target spot is turned from empty to full.
Thinking about this, I want to flip three bits simulataneously.  So I recode
a bit:

```lisp
(defun reverse-3-bits (state bits)
  (loop with result = (copy-seq state)
        for bit in bits
	for bit-number from 0 to 2
        do (setf (aref result bit) (logxor 1 (aref result bit)))
	finally (return result)))
```

The BIT-NUMBER part above is a kind of hack.  When writing NEXT-STATES before,
I realized that Lisp's LOOP ... ON is a useful way to iterate over a sequence of
holes.  If we do:

```lisp
(loop for i on '(0 1 3 6 10)
      do (format t "~A~%" i))
```

We get the following output:

    (0 1 3 6 10)
    (1 3 6 10)
    (3 6 10)
    (6 10)
    (10)
    NIL

Limiting the bits reversed to 3 means that we can pass a reference to a sequence
longer than three bits and reverse only the first three bits.

Whew.

Well, the next thing we want to know is whether we can make a jump, given three
consecutive holes.  Let's try:

```lisp
(defun can-jump (state bits)
  (and (>= (length bits) 3)
       (= 1 (aref state (second bits)))
       (not (= (aref state (first bits))
               (aref state (third bits))))))
```

Hah.  The beatiful trick here is this:  The middle hole has to be filled, of
course, and _one_ of the holes on either end must be filled while the other
must be empty.  This catches whether a jump can be made _in either direction_.
Which is pretty cool, because REVERSE-3-BITS will make the correct result
regardless of the direction.

A little bit of testing in the REPL, and success!

OK, let's go back to NEXT-STATES and try again now that we have some cool
tools.

```lisp
(defun next-states (state)
  (loop with result = ()
	for sequence in *sequences*
	do (loop for possible-jump on sequence
		 when (can-jump state possible-jump)
		 do (push (reverse-3-bits state possible-jump) result))
	finally (return result)))
```

A few attempts with this in the REPL and it seems to work!

    * (next-states *start-state*)

    (#*101011111111111 #*110110111111111)
    * (mapcar #'next-states (next-states *start-state*))

    ((#*101100111111111 #*101111011101111 #*101111101111011 #*111001110111111)
     (#*110001111111111 #*110111110111011 #*111100101111111 #*110111111011110))

So now what?

What we want to accomplish is finding a sequence of moves which wins the game.
We have the starting board configuration.  We know how to compute, given one
board configuration, all the possible board configurations after the next move.

Normally, I'd do this with something like a depth-first search or a
breadth-first search.  I almost always prefer breadth-first search, but as
I think about it, a neat kind of variation on BFS appears where each level
is computed successively.  I mean, we start with the start state, then
we figure out all the possible states after one move, then all the possible
states after two moves.

```lisp
(defun solve ()
  (let ((states (list *start-state*)))
    (loop
      (if (find-if #'end-state-p states)
	(return t))
      (setf states (mapcan #'next-states states))
      (if (null states)
	(return nil)))))
```

This is the first draft.  It only recursively makes moves until it finds
a solution.  It returns T if it does, or NIL if it does not.  It returns
T.  I don't have a very high level of confidence that the code is correct,
though it's comforting that it takes about three seconds to run on my
laptop.

The next part is wanting to find a sequence of moves that solves the
problem.  This is where the bit representation and the array stuff comes
in handy.  But... I still don't know how to convert a bit vector to an
integer.  After some Googling... well, there isn't a standard way. Some
people have some nifty functions to do it, but... why am I using bit
vectors anyway?  Apparently, I can use `#b` to prefix a binary literal
as an integer, and do different kinds of math on it with the LOG
operators.

OK.

A flurry of searching and replacing different expressions and rewriting
little bits.  A little bit of worry.  I end up with the following code:

```lisp
(defvar *start-state* #b111111111111110)

(defun end-state-p (state)
  (= 1 (logcount state)))

(defvar *sequences* '((0 2 5 9 14) ; Moving down and right
                      (1 4 8 13)
		      (3 7 12)
		      (0 1 3 6 10) ; Moving down and left
		      (2 4 7 11)
		      (5 8 12)
		      (3 4 5)      ; Moving left-to-right
		      (6 7 8 9)
		      (10 11 12 13 14)))

(defun reverse-3-bits (state bits)
  (loop with result = state
        for bit in bits
	for bit-number from 0 to 2
        do (setf result (logxor (ash 1 bit) result))
	finally (return result)))

(defun can-jump (state bits)
  (and (>= (length bits) 3)
       (logtest state (ash 1 (second bits)))
       (not (eq (logtest state (ash 1 (first bits)))
		(logtest state (ash 1 (third bits)))))))

(defun next-states (state)
  (loop with result = ()
	for sequence in *sequences*
	do (loop for possible-jump on sequence
		 when (can-jump state possible-jump)
		 do (push (reverse-3-bits state possible-jump) result))
	finally (return result)))

(defun solve ()
  (let ((states (list *start-state*)))
    (loop
      (if (find-if #'end-state-p states)
	(return t))
      (setf states (mapcan #'next-states states))
      (if (null states)
	(return nil)))))
```

It doesn't blow up, and runs in the same amount of time.  How much
confidence does that give me that it's correct?  Hrmm.  After looking
over the code, I think that if it were wrong, it would blow up or
return immediately or not return.  Of course, there could be some kind
of off-by-one introduced, but I don't see it.

So now we can add an array which can point from each state to its
previous state.  This can be used to trace the path backward from
a successful goal to the start state.

```lisp
(defun solve ()
  (let ((states (list *start-state*))
	(found (make-array 32768 :initial-element -1))
	(states-for-next-iteration ()))
    (loop
      (setf states-for-next-iteration ())

      (dolist (state states)
	(if (end-state-p state)
	  (let ((path ()))
	    (loop while (not (= state -1))
		  do (push state path)
		     (setf state (aref found state)))
	    (return-from solve path)))

	(dolist (next-state (next-states state))
	  (if (= -1 (aref found next-state))
	    (progn
	      (setf (aref found next-state) state)
	      (push next-state states-for-next-iteration)))))
      (setf states states-for-next-iteration)
      (if (null states)
	(return-from solve nil)))))
```

Writing this was kind of painful.  At first, it simply printed
NIL.  I restructured some, kind of without understanding why it
didn't work and it again printed T.  Then using the array sped
up the computation (as expected - states are no longer visited
more than once).

Finally, code was added to reconstruct the path and return it
when a goal state was found.  I put this inline and reused a
variable (yuck).  It gives the following output:

    (32766 32731 32739 31659 31713 27497 7017 9065 8995 8455 23 50 10 64)

Well... Huh.  What does it mean?

So we need a function to print a state in a way we can understand.

```lisp
(defvar *template*
  (concatenate 'string
    "    ~A~%"
    "   ~A ~A~%"
    "  ~A ~A ~A~%"
    " ~A ~A ~A ~A~%"
    "~A ~A ~A ~A ~A~%"
    "~%"))

(defun print-state (state)
  (apply #'format t *template*
	 (loop for i from 0 to 14
	       collect (if (logtest (ash 1 i) state)
			 "X"
			 "."))))
```

Now we can run the following from the REPL:

```lisp
(mapc #'print-state (solve))
```

And we get the following output:

	.
       X X
      X X X
     X X X X
    X X X X X

	X
       X .
      X X .
     X X X X
    X X X X X

	X
       X .
      . . X
     X X X X
    X X X X X

	X
       X .
      X . X
     . X X X
    . X X X X

	X
       . .
      . . X
     X X X X
    . X X X X

	X
       . .
      X . X
     X . X X
    . X . X X

	X
       . .
      X . X
     X . X X
    . X X . .

	X
       . .
      X . X
     X . X X
    . . . X .

	X
       X .
      . . X
     . . X X
    . . . X .

	X
       X X
      . . .
     . . X .
    . . . X .

	X
       X X
      . X .
     . . . .
    . . . . .

	.
       X .
      . X X
     . . . .
    . . . . .

	.
       X .
      X . .
     . . . .
    . . . . .

	.
       . .
      . . .
     X . . .
    . . . . .

