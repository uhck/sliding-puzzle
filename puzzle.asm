TITLE      (.asm)

INCLUDE Irvine32.inc

Node STRUCT
	parent DWORD 0
	set BYTE 9 DUP(?)
	pos0 BYTE 9
	prev0 BYTE 9
	sibling DWORD 0
Node ENDS

.data
                                                               ; TREE DATA
MAXSTR  = 80                                                   ; Max number of bytes in filename
MAXI = 8                                                       ; Max index
WID = 3                                                        ; Value to move node up or down
TRUE = 1                                                       ; To check if found is true
NSET = 4                                                       ; Offset to set of a node
NPOS0 = 13                                                     ; Offset to pos0 of a node
NPREV0 = 14                                                    ; Offset to prev0 of a node
SIB = 15                                                       ; Offset to sibling of a node
hHeap DWORD ?                                                  ; Heap handler
dwFlags DWORD HEAP_ZERO_MEMORY                                 ; Initialize heap memory to 0
head DWORD ?                                                   ; Head of linked list structure (for tree)
tail DWORD ?                                                   ; Tail of linked list structure (for tree)
root Node <0,<49,50,51,52,53,54,55,56,48>,MAXI,>               ; Root of tree
filename BYTE MAXSTR+1 DUP(?)                                  ; File name string
prompt BYTE "Enter file name: ",0                              ; Prompt user for file name
found BYTE 0                                                   ; Found last node (goal) in tree
goal Node <>                                                   ; Stores goal node to build tree
genArray BYTE 9 DUP(0)                                         ; Used to generate map

                                                                            ; MENU DATA
menuBegin BYTE "Hello! Welcome to the puzzle. ", 0dh, 0ah,					; Menu intro
		"Please select one of the following: ", 0dh, 0ah,
		"a) Start New Game (s)", 0dh, 0ah,
		"b) Generate Map (g)", 0dh, 0ah,
		"c) Demo Mode (m)", 0dh, 0ah,
		"d) End Game (e)", 0dh, 0ah,
		"Selection: ", 0
menuFull BYTE "Please select one of the following: ", 0dh, 0ah,				; Menu with all options 
		"a) Start New Game (s)", 0dh, 0ah,	
		"b) Print Map (p)", 0dh, 0ah,
		"c) Hint (h)", 0dh, 0ah,
		"d) Move Up (u)", 0dh, 0ah,	
		"e) Move Down (d)", 0dh, 0ah,	
		"f) Move Left (l)", 0dh, 0ah,	
		"g) Move Right (r)", 0dh, 0ah,	
		"h) End Game (e)", 0dh, 0ah, 
		"Selection: ", 0
menuEnd BYTE "Congratulations! You have solved the puzzle!", 0dh, 0ah,		; Menu with ending options
		"Please select one of the following: ", 0dh, 0ah,	
		"a) Start New Game (s)", 0dh, 0ah,	
		"b) Print Map (p)", 0dh, 0ah,	
		"c) End Game (e)", 0dh, 0ah, 
		"Selection: ", 0
gameEnd BYTE "You have selected to end the game.", 0dh, 0ah,							; Ending statement
		"Ending game...", 0	
moveError BYTE "Error! The tile you want to move 0 to does not exist.",0dh,0ah,0	; Error message if desired move can't be done.
nSolveFile BYTE "Error! The pattern from file is not solvable.", 0dh, 0ah, 0dh, 0ah,		; Error if not solvable
		"Please select one of the following: ", 0dh, 0ah,
		"a) Start New Game (s)", 0dh, 0ah,
		"b) Generate Map (g)", 0dh, 0ah,
		"c) Demo Mode (m)", 0dh, 0ah,
		"d) End Game (e)", 0dh, 0ah,
		"Selection: ", 0
charIn BYTE ?																		; User character input for menu
game Node <>									       ; Input node of user
gEnd Node <0,<49,50,51,52,53,54,55,56,48>,1>		   ; Goal node for user 

.code

main PROC
	INVOKE GetProcessHeap                              ; Get handle heap
	mov   hHeap, eax

	call Clrscr
	; GAME
	 mov   esi, OFFSET game
	 call  userStart
	 mov   esi, OFFSET game
	 call  userOption
	 call  userLoop
	 call  nukem
	exit
main ENDP

;-----------------------------------------------------
; inputFile
;
; Asks user for input file and reads random puzzle into goal node's set.
; Receives: ESI = offset to goal node
; Returns:	None
;-----------------------------------------------------
inputFile PROC
	mov   edx, OFFSET prompt                           ; Get file name
	call  WriteString
	mov   edx, OFFSET filename                         ; Store file name
	mov   ecx, MAXSTR
	call  ReadString
	call  OpenInputFile                                ; Open input file
	mov   edx, esi                                     ; Move offset memory from ESI to EDX
	add   edx, NSET
	mov   ecx, MAXI+1
	call  ReadFromFile                                 ; Read file contents to offset memory in EDX
	ret
inputFile ENDP

;-----------------------------------------------------
; generateMap
;
; Creates a random, solvable map for game.
; Receives: ESI = offset to node
; Returns:	None
;-----------------------------------------------------
generateMap PROC
G1:	call  Randomize								       ; Re-seeds
	mov   edi, OFFSET genArray
	mov   ebx, 0									   ; Keeps track of puzzle position
	mov   ecx, MAXI+1                                  ; Number of values that need to be generated
G2:	mov   eax, MAXI+1                                  ; Sets boundary for random numbers 0-8
	call  RandomRange                                  ; Generate random number
	cmp   BYTE PTR [edi+eax], TRUE                     ; If number has already been selected
	je    G2                                           ; Generate another random number
	mov   BYTE PTR [edi+eax], TRUE                     ; Mark number that has been selected as TRUE
	add   eax, 30h                                     ; Convert integer to ASCII character
	mov   [esi+NSET+ebx], eax                          ; Store character to esi set
	inc   ebx                                          ; Increment ebx to next puzzle position
	LOOP  G2                                           ; Generate next number in goal puzzle
	call  isSolvable                                   ; Checks if randomly generated puzzle is solvable
	mov   ecx, MAXI+1
	mov   DWORD PTR [genArray], 0                      ; Reset genArray to 0
	mov   DWORD PTR [genArray+4], 0
	mov   BYTE PTR [genArray+8], 0
	cmp   eax, 0                                       ; If generated puzzle isn't solvable, regenerate it
	je    G1
	ret
generateMap ENDP

;-----------------------------------------------------
; demoGame
;
; Displays demo of game to user.
; Receives: ESI = offset to head node of linked list
; Returns:	None
;-----------------------------------------------------
demoGame PROC
	mov esi, OFFSET game                               ; Generates random puzzle to game
	call generateMap
	mov edi, OFFSET game
	mov edx, OFFSET goal
	call copyNode                                      ; Copies set from game to goal
	mov esi, OFFSET root
	call buildTree                                     ; Build tree and display fastest path
	call displayPath
	call nukem
demoGame ENDP

;-----------------------------------------------------
; buildTree
;
; Create linked list based tree of game decisions.
; Receives: ESI = offset to first child of the tree
; Returns:	ESI = offset to target node
;-----------------------------------------------------
buildTree PROC
	mov   eax, 0
	mov   found, 0
	mov   head, esi
	mov   tail, esi
B1:	mov   al, [esi+NPOS0]                              ; Swap left (bh = new pos0)
	dec   al
	cmp   [esi+NPREV0], al                             ; Checks if prev0 = new pos0, skip
	je    M1
	cmp   al, MAXI                                     ; Checks if new pos0 is out of bounds, skip
	ja    M1
	mov   bl, 3
	cmp   [esi+NPOS0], bl                              ; Cannot move left if pos0 = 3 or 6
	je    M1
	mov   bl, 6
	cmp   [esi+NPOS0], bl
	je    M1
	call  makeChild                                    ; Make new child node
M1:	mov   al, [esi+NPOS0]                              ; Swap right
	inc   al
	cmp   [esi+NPREV0], al
	je    M2
	cmp   al, MAXI
	ja    M2
	mov   bl, 2
	cmp   [esi+NPOS0], bl                              ; Cannot move right if pos0 = 2 or 5
	je    M2
	mov   bl, 5
	cmp   [esi+NPOS0], bl
	je    M2
	call  makeChild
M2: mov   al, [esi+NPOS0]                              ; Swap top
	sub   al, WID
	cmp   [esi+NPREV0], al
	je    M3
	cmp   al, MAXI
	ja    M3
	call  makeChild
M3: mov   al, [esi+NPOS0]                              ; Swap bottom
	add   al, WID
	cmp   [esi+NPREV0], al
	je    M4
	cmp   al, MAXI
	ja    M4
	call  makeChild
M4: mov   al, TRUE                                     ; Check if found = TRUE, then return
	cmp   found, al
	je    M5
	mov   esi, [esi+SIB]                               ; Repeat if there exists a sibling
	jne   B1
M5:	ret
buildTree ENDP

;-----------------------------------------------------
; makeChild
;
; Initialize a new child in children array and set up its parent, set, pos0, prev0, previous sibling.
; Receives: ESI = offset to parent node
; Returns:	EDI = offset to newly created child
;-----------------------------------------------------
makeChild PROC
	push  eax                                          ; Push value of EAX into stack
	INVOKE heapAlloc, hHeap, dwFlags, SIZEOF Node      ; Create new node and move to EDI
	mov   edi, eax
	mov   eax, tail
	mov   [eax+SIB], edi                               ; Set previous node's sibling to new node
	mov   [edi], esi                                   ; Set new child node's parent
	pop   eax                                          ; Pop original value into EAX
	mov   ecx, MAXI+1
	mov   edx, 0
C1:	mov   bl, [esi+NSET]+[edx]                         ; Set child set = parent set
	mov   [edi+NSET]+[edx], bl
	inc   edx
	LOOP  C1
	movzx edx, BYTE PTR [esi+NPOS0]
	mov   bl, [esi+NSET]+[edx]                         ; Swap 0 to its new position (BH)
	mov   bh, [esi+NSET]+[eax]
	mov   [edi+NSET]+[eax], bl
	mov   [edi+NSET]+[edx], bh
	mov   [edi+NPOS0], al                              ; Set pos0 of new child
	mov   bl, [esi+NPOS0]
	mov   [edi+NPREV0], bl                             ; Set prev0 of new child
	mov   edx, OFFSET goal
	call  checkGoal                                    ; Check if new node is target node
	mov   tail, edi
	ret
makeChild ENDP

;-----------------------------------------------------
; checkGoal
;
; Checks if goal set has been reached and sets found to TRUE
; Receives: EDI = offset to node
;           EDX = offset to goal node
; Returns:	None
;-----------------------------------------------------
checkGoal PROC
	mov   ecx, 0
H1: mov   bl, [edx+NSET]+[ecx]                         ; Check if child set matches goal set
	mov   bh, [edi+NSET]+[ecx]
	cmp   bh, bl
	jne   H3                                           ; If there's any numbers that don't match up, return
	inc   ecx
	cmp   ecx, MAXI+1
	jne   H1
H2:	mov   found, TRUE                                  ; If all numbers match up, change found to 1
	mov   esi, edi
H3:	ret
checkGoal ENDP

;-----------------------------------------------------
; displaySet
;
; Outputs set to console.
; Receives: EDX = offset to any node
; Returns:	None
;-----------------------------------------------------
displaySet PROC
	mov   ecx, MAXI+1                                  ; Output set to console
	mov   ebx, 0
D1:	mov   al, BYTE PTR [edx+NSET+ebx]
	call  WriteChar
	inc   ebx
	cmp   ebx, WID
	je    D3
D2: LOOP  D1
	ret
D3: call  Crlf
	add   edx, ebx
	mov   ebx, 0
	jmp   D2
displaySet ENDP

;-----------------------------------------------------
; displayPath
;
; Outputs path from target to root node in console.
; Receives: ESI = offset to target node
; Returns:	None
;-----------------------------------------------------
displayPath PROC
	mov   edx, esi                                     ; Output target node
	call  displaySet
	call  Crlf
P1: mov   edx, [esi]                                   ; Go to parent or target node
	mov   esi, [esi]
	call  displaySet
	call  Crlf
	cmp   BYTE PTR [esi], 0
	jne   P1                                           ; Repeat
	ret
displayPath ENDP

;-----------------------------------------------------
; nukem
;
; Delete nodes and free heap memory.
; Receives: ESI = offset to head of linked list
; Returns:	None
;-----------------------------------------------------
nukem PROC
	INVOKE heapFree, hHeap, dwFlags, [esi]             ; Delete node pointed to by EDI
	ret
nukem ENDP

;-----------------------------------------------------
; isSolvable
;
; Counts number of inversions in a set and determines whether or not it is solvable.
; Receives: ESI = offset to node
; Returns:	EAX = 0 for unsolvable, 1 for solvable
;-----------------------------------------------------
isSolvable PROC
	mov   eax, 0                                       ; use EAX as inversion counter
	mov   ebx, 0
S1:	cmp   BYTE PTR [esi+NSET+ebx], 48                  ; if set[i] == 0, skip to next digit
	je    S4
	mov   ecx, ebx
S2:	inc   ecx
	cmp   BYTE PTR [esi+NSET+ecx], 48                  ; if set[j] == 0, skip to next digit
	je    S3
	mov   ah, BYTE PTR [esi+NSET+ebx]                  ; if set[i] < set[j], increment j
	cmp   ah, BYTE PTR [esi+NSET+ecx]
	jb    S3
	inc   al                                           ; otherwise, increment inversion counter
S3:	cmp   ecx, MAXI
	jb    S2
S4:	inc   ebx                                          ; go to next i value
	cmp   ebx, MAXI-1
	jbe   S1
S5:	jz    S6
	js    S7
	sub   al, 2                                        ; subtract 2 from inversion counter
	jmp   S5
S6: mov   eax, TRUE
	ret
S7: mov   eax, 0
	ret
isSolvable ENDP

;-----------------------------------------------------
; userStart
;
; Outputs menu start.
; Receives: None
; Returns: charIn = user input option
;-----------------------------------------------------
userStart PROC
	mov edx, OFFSET menuBegin
	call WriteString
	call ReadChar
	mov charIn, al
	call WriteChar
	call Crlf
	ret
userStart ENDP

;-----------------------------------------------------
; userMenuF
;
; Displays full menu.
; Receives: None.
; Returns: charIn = user input option
;-----------------------------------------------------
userMenuF PROC
	mov edx, OFFSET menuFull
	call WriteString
	call ReadChar
	mov charIn, al
	call WriteChar
	call Crlf
	ret
userMenuF ENDP

;-----------------------------------------------------
; userEnd
;
; Displays ending menu.
; Receives: None.
; Returns: charIn = user input option
;-----------------------------------------------------
userEnd PROC
	mov edx, OFFSET menuEnd
	call WriteString
	call ReadChar
	mov charIn, al
	call WriteChar
	call Crlf
	call Crlf
	ret
userEnd ENDP

;-----------------------------------------------------
; userFileError
;
; Displays error if inputFile pattern is not solvable.
; Receives: None.
; Returns: charIn = user input option
;-----------------------------------------------------
userFileError PROC
	call Crlf
	mov edx, OFFSET nSolveFile	
	call WriteString							; error if not solvable
	call ReadChar
	mov charIn, al
	call WriteChar
	call Crlf
	ret
userFileError ENDP

;-----------------------------------------------------
; userOption
;
; Compares user character input and performs appropriate option.
; Receives: charIn = user input
; Returns: None.
;-----------------------------------------------------
userOption PROC
S7:	cmp al, 115									; Start New Game (input file)
	je S9
	cmp al, 103                                 ; Generate Random Map
	je G9
	cmp al, 112                                 ; Display Map
	je P9
	cmp al, 104                                 ; Builds tree and displays hint
	je H9
	cmp al, 117                                 ; Swap up
	je U9
	cmp al, 100                                 ; Swap down
	je D9
	cmp al, 108                                 ; Swap left
	je L9
	cmp al, 114                                 ; Swap Right
	je R9
	cmp al, 109                                 ; Demo game (generates map + displays fastest path)
	je M9
	cmp al, 101                                 ; Exit game
	je E9
	
S9:	mov esi, OFFSET game
	call inputFile								; imports set from file
	call isSolvable
	cmp eax, TRUE
	je S8
	call userFileError							; error if inputFile pattern is not solvable
	jmp S7
S8: jmp R8

G9: mov   esi, OFFSET game                      ; generates map for game
	call  generateMap
	mov   edx, esi
	jmp R8

P9: call Crlf
	mov edx, OFFSET game						; displays set 
	call displaySet
	jmp R8

H9:	call Crlf
	mov edi, OFFSET game                        ; builds tree to game puzzle and displays hint (parent of goal)
	mov edx, OFFSET goal
	call copyNode
	mov esi, OFFSET root
	call buildTree
	mov esi, [esi]
	mov edx, esi
	call displaySet
	jmp R8

U9:	mov esi, OFFSET game						; switches with above tile
	call locateZero
	call moveUp
	jmp R8

D9:	mov esi, OFFSET game						; switches with below tile
	call locateZero
	call moveDown
	jmp R8

L9:	mov esi, OFFSET game						; switches with left tile
	call locateZero							
	call moveLeft
	jmp R8

R9:	mov esi, OFFSET game						; switches with right tile
	call locateZero
	call moveRight
	jmp R8

M9: call demoGame                               ; demonstrates how to play game
	mov  esi, OFFSET game
	call userStart
	mov esi, OFFSET game
	call userOption
	jmp R8


E9:	call Crlf
	mov edx, OFFSET gameEnd						; ends game
	call WriteString
	call Crlf
	call nukem
	exit
	
R8:	call Crlf
	ret
userOption ENDP

;-----------------------------------------------------
; copyNode
;
; Receives: EDI = source
;           EDX = destination
; Returns:  None
;-----------------------------------------------------
copyNode PROC
	mov ebx, 0
	mov ecx, SIZEOF Node
P1: mov eax, [edi+ebx]
	mov [edx+ebx], eax
	inc ebx
	LOOP P1
	ret
copyNode ENDP

;-----------------------------------------------------
; locateZero
;
; Finds the location of zero in the node.
; Receives: ESI = OFFSET of target
; Returns: ESI = OFFSET of zero in node
;-----------------------------------------------------
locateZero PROC
	mov ecx, 0
Z9:	mov al, [esi+ecx]
	inc ecx
	cmp al, 30h
	jne Z9
	add esi, ecx
	sub esi, 1
	ret
locateZero ENDP

;-----------------------------------------------------
; moveUp
;
; Switches zero with value above.
; Receives: ESI = OFFSET of zero in set.
; Returns: None.
;-----------------------------------------------------
moveUp PROC
	mov al, [esi]
	mov bl, [esi-3]

	mov edi, OFFSET game						; OFFSET game (esi) - OFFSET game (edi)
	mov edx, esi
	sub edx, edi
	cmp edx, 6									; if result = 1,2,3, jumps to error
	je E7
	cmp edx, 5
	je E7
	cmp edx, 4									
	je E7

	mov [esi], bl								; if not, switches the values
	mov [esi-3], al
	ret
E7: call Crlf
	mov edx, OFFSET moveError
	call WriteString
	ret
moveUp ENDP

;-----------------------------------------------------
; moveDown
;
; Switches zero with value below.
; Receives: ESI = OFFSET of zero in set.
; Returns: None.
;-----------------------------------------------------
moveDown PROC
	mov al, [esi]
	mov bl, [esi+3]
	
	mov edi, OFFSET game						; OFFSET game (esi) - OFFSET game (edi)
	mov edx, esi
	sub edx, edi
	cmp edx, 12									; if result = 7,8,9, jumps to error
	je D8
	cmp edx, 11
	je D8
	cmp edx, 10
	je D8

	mov [esi], bl								; if not, switches the values
	mov [esi+3], al
	ret
D8: call Crlf
	mov edx, OFFSET moveError
	call WriteString
	ret
moveDown ENDP

;-----------------------------------------------------
; moveLeft
;
; Switches zero with value on the left.
; Receives: ESI = OFFSET of zero in set.
; Returns: None.
;-----------------------------------------------------
moveLeft PROC
	mov al, [esi]
	mov bl, [esi-1]
	mov edi, OFFSET game						; OFFSET game (esi) - OFFSET game (edi)
	mov edx, esi	
	sub edx, edi
	cmp edx, 4									; if result = 1,4,7, jumps to error
	je L8
	cmp edx, 7
	je L8
	cmp edx, 10
	je L8

	mov [esi], bl								; if not, switches the values
	mov [esi-1], al
	ret
L8: call Crlf
	mov edx, OFFSET moveError
	call WriteString
	ret
moveLeft ENDP

;-----------------------------------------------------
; moveRight
;
; Switches zero with value on the right.
; Receives: ESI = OFFSET of zero in set.
; Returns: None.
;-----------------------------------------------------
moveRight PROC
	mov al, [esi]
	mov bl, [esi+1]
	mov edi, OFFSET game						; OFFSET game (esi) - OFFSET game (edi)
	mov edx, esi
	sub edx, edi
	cmp edx, 6									; if result = 3,6,9, jumps to error
	je R7
	cmp edx, 9
	je R7
	cmp edx, 12
	je R7
	mov [esi], bl								; if not, switches the values
	mov [esi+1], al
	ret
R7: call Crlf
	mov edx, OFFSET moveError
	call WriteString
	ret
moveRight ENDP

;-----------------------------------------------------
; userLoop
;
; Entire loop for the user to play the game.
; Receives: None.
; Returns: None.
;-----------------------------------------------------
userLoop PROC
	jmp L1
E6:	mov esi, OFFSET game
	call userOption
L1:	call userMenuF
	call userOption
	call Crlf
	mov edi, OFFSET game
	mov edx, OFFSET gEnd
	mov found, 0
	call checkGoal
	mov al, TRUE
	cmp found, al
	je E8
	jmp L1
E8: call userEnd
	cmp al, 115										; if user enters s, jumps up to the start
	je E6
	cmp al, 112										; if user enters p, jumps to print, then 
	je E5
	mov edx, OFFSET gameEnd							; if user enters e or anything else, ends
	call WriteString
	call Crlf
	call nukem
	exit
E5: mov edx, OFFSET game
	call displaySet
	call Crlf
	jmp E8
	ret
userLoop ENDP

END main