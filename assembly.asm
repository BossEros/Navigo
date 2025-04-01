.model small
.stack 100h

.data
    message db "Number Counter: $" 
    space db " $"
    doneMessage db 13, 10, "Done!$"

.code
main:
   MOV AX, @DATA
   MOV DS, AX
   
   MOV AH, 09H
   MOV DX, OFFSET Message
   INT 21H

   MOV DL, 1
   ADD DL, 30H
   MOV AH, 02H
   INT 21H

   MOV AH, 4CH 
   INT 21H

end main
