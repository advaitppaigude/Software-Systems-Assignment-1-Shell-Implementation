#include "s3.h"
#include <string.h>

/// ===========================================================================
/// PERSON 2 (Srivathsan): Prompt & cd (Sec 3), Batched Commands (Sec 5), Subshells (Sec 6-7)
/// ===========================================================================

///Simple for now, but will be expanded in a following section
void construct_shell_prompt(char shell_prompt[], char lwd[])
{
    char cwd[MAX_PROMPT_LEN - 7];
    if (getcwd(cwd, sizeof(cwd)) == NULL) {
        strcpy(cwd, lwd);
    }
    snprintf(shell_prompt, MAX_PROMPT_LEN, "[%s s3]$ ", cwd);
}

///Prints a shell prompt and reads input from the user
void read_command_line(char line[], char lwd[])
{
    char shell_prompt[MAX_PROMPT_LEN];
    construct_shell_prompt(shell_prompt, lwd);
    printf("%s", shell_prompt);

    ///See man page of fgets(...)
    if (fgets(line, MAX_LINE, stdin) == NULL)
    {
        perror("fgets failed");
        exit(1);
    }
    ///Remove newline (enter)
    line[strlen(line) - 1] = '\0';
}

void parse_command(char line[], char *args[], int *argsc)
{
    ///Implements simple tokenization (space delimited)
    ///Note: strtok puts '\0' (null) characters within the existing storage, 
    ///to split it into logical cstrings.
    ///There is no dynamic allocation.

    ///See the man page of strtok(...)
    char *token = strtok(line, " ");
    *argsc = 0;
    while (token != NULL && *argsc < MAX_ARGS - 1)
    {
        args[(*argsc)++] = token;
        token = strtok(NULL, " ");
    }
    
    args[*argsc] = NULL; ///args must be null terminated
}

/// (Add additional Srivathsan / Person 2 functions below)

void init_lwd(char lwd[]){
    if (getcwd(lwd, MAX_PROMPT_LEN - 6) == NULL){ //writes getcwd to lwd
        perror("getcwd failed"); // 
    }
}

int is_cd(char line[]){
    int i = 0; //getting rid of leading spaces
    while (line[i] == ' ') {
        i++;
    }
    if (line[i] =='c' && line[i+1] == 'd' && (line[i+2] == ' ' || line[i+2] == '\0')) {
        return 1;
    }else{
        return 0;
    }
}

void run_cd(char *args[], int argsc, char lwd[]){
    // Save current directory
    char temp[MAX_PROMPT_LEN - 6];
    getcwd(temp, sizeof(temp));

    int rc;
    // Situation 1: cd (change to home directory)
    if ((argsc == 1) && (args[1] == NULL)){
        rc = chdir(getenv("HOME"));
    } else if ((argsc == 2) && strcmp(args[1], "-") == 0){
        // Situation 2: cd - (go back to previous lwd)
        rc = chdir(lwd);
    } else {
        // Situation 3 & 4: cd .. or cd <folder>
        rc = chdir(args[1]);
    }

    // Only update lwd if chdir succeeded (returned 0)
    if (rc == 0) {
        strcpy(lwd, temp);
    } else {
        perror("cd failed");
    }
}



/// ===========================================================================
/// PERSON 1 (Advait): Basic Execution (Sec 1), Redirection (Sec 2), Pipelines (Sec 4)
/// ===========================================================================

///Launch related functions
void child(char *args[], int argsc)
{
    ///Implement this function:

    ///Use execvp to load the binary 
    ///of the command specified in args[ARG_PROGNAME].
    ///For reference, see the code in lecture 3.

    execvp(args[ARG_PROGNAME], args);
    // wont reach the code below if execvp successful
    perror("execvp");
    _exit(EXIT_FAILURE);
}

void launch_program(char *args[], int argsc)
{
    ///Implement this function:

    ///fork() a child process.
    ///In the child part of the code,
    ///call child(args, argv)
    ///For reference, see the code in lecture 2.

    if (args[ARG_PROGNAME] == NULL) {
        return;
    }
    else {
        if (strcmp(args[ARG_PROGNAME], "exit") == 0) {
            exit(EXIT_SUCCESS);
        }
    
        int rc = fork();
    
        if (rc < 0) {
            printf("fork failed\n");
        }
        else if (rc == 0) {
            child(args, argsc);
        }
    }

    ///Handle the 'exit' command;
    ///so that the shell, not the child process,
    ///exits.
}

/// (Add additional Advait / Person 1 functions below)
