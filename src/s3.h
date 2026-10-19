#ifndef _S3_H_
#define _S3_H_

///See reference for what these libraries provide
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>

///Constants for array sizes, defined for clarity and code readability
#define MAX_LINE 1024
#define MAX_ARGS 128
#define MAX_PROMPT_LEN 256

///Enum for readable argument indices (use where required)
enum ArgIndex
{
    ARG_PROGNAME,
    ARG_1,
    ARG_2,
    ARG_3,
};

// enum to represent redirection type
typedef enum RedirectType {
    REDIR_NONE,
    REDIR_INPUT,
    REDIR_OUTPUT,
    REDIR_APPEND
} RedirectType;


typedef struct {
    RedirectType type;
    char *filename;
} Redirection;



///With inline functions, the compiler replaces the function call 
///with the actual function code;
///inline improves speed and readability; meant for short functions (a few lines).
///the static here avoids linker errors from multiple definitions (needed with inline).
static inline void reap()
{
    wait(NULL);
}

///Shell I/O and related functions (add more as appropriate)
void read_command_line(char line[], char lwd[]);
void construct_shell_prompt(char shell_prompt[], char lwd[]);
void parse_command(char line[], char *args[], int *argsc);

/// ===========================================================================
/// PERSON 2 (Srivathsan): cd & Prompt (Sec 3), Batched Commands (Sec 5), Subshells (Sec 6-7)
/// (Add Person 2 / Srivathsan function declarations below)
/// ===========================================================================

/// cd is goes into or out of a directory
/// Initializes lwd with the starting current working directory (using getcwd)
void init_lwd(char lwd[]);

/// Returns 1 (true) if the command line is a 'cd' command, 0 (false) otherwise
int is_cd(char line[]);

/// Executes the 'cd' built-in command and updates lwd
void run_cd(char *args[], int argsc, char lwd[]);

/// ===========================================================================
/// PERSON 1 (Advait): Basic Execution (Sec 1), Redirection (Sec 2), Pipelines (Sec 4)
/// (Add Person 1 / Advait function declarations below)
/// ===========================================================================

///Child functions (add more as appropriate)
void child(char *args[], int argsc);

///Program launching functions (add more as appropriate)
void launch_program(char *args[], int argsc, Redirection *redir);


int parse_redirection(char *args[], int *argsc, Redirection *redir);
int apply_redirection(const Redirection *redir);

int parse_pipe(char *args[], int *argsc, char **commands[], int *num_commands);
int launch_pipeline(char **commands[], int num_commands);

#endif
