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
#include <signal.h>
#include <glob.h>
#include <termios.h> 


///Constants for array sizes, defined for clarity and code readability
#define MAX_LINE 1024
#define MAX_ARGS 128
#define MAX_PATH_LEN 512
#define MAX_PROMPT_LEN 1024
#define MAX_HISTORY 100

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
/// ===========================================================================

/// Initializes lwd with the starting current working directory (using getcwd)
void init_lwd(char lwd[]);

/// Returns 1 (true) if the command line is a 'cd' command, 0 (false) otherwise
int is_cd(char line[]);

/// Executes the 'cd' built-in command and updates lwd
void run_cd(char *args[], int argsc, char lwd[]);

/// Splits multi-command statements on top-level ';' for sequential execution 
void parse_batched_commands(char line[], char *batch_cmds[], int *batch_count);

/// checking if a subshell is needed
int is_subshell(char line[]); // like is_cd() returns 1 if the command batch is a subshell (...)

/// launches a child s3 shell process to execute a subshell command
void launch_subshell(char line[], char shell_path[]);

/// helper function to find parenthesis in command
int find_subshell_bounds(char line[], int *start, int *end);

/// helper function for expanding glob wildcard inputs (* and ?)
void expand_globs(char *args[], int *argsc);

/// helper functions for history features
void add_to_history(char line[]);
/// ===========================================================================
/// PERSON 1 (Advait): Basic Execution (Sec 1), Redirection (Sec 2), Pipelines (Sec 4)
/// ===========================================================================

///Child functions
void child(char *args[], int argsc);

///Program launching functions
void launch_program(char *args[], int argsc, Redirection *redir);


int parse_redirection(char *args[], int *argsc, Redirection *redir);
int apply_redirection(const Redirection *redir);

int parse_pipe_stages(char line[], char *pipe_stages[], int *num_stages);
int launch_pipeline_stages(char *pipe_stages[], int num_stages, char shell_path[]);

#endif
