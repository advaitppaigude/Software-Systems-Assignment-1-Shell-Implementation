#include "s3.h"
#include <string.h>

/// ===========================================================================
/// PERSON 2 (Srivathsan): Prompt & cd (Sec 3), Batched Commands (Sec 5), Subshells (Sec 6-7)
/// ===========================================================================

///Simple for now, but will be expanded in a following section
void construct_shell_prompt(char shell_prompt[])
{
    strcpy(shell_prompt, "[s3]$ ");
}

///Prints a shell prompt and reads input from the user
void read_command_line(char line[])
{
    char shell_prompt[MAX_PROMPT_LEN];
    construct_shell_prompt(shell_prompt);
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

void launch_program(char *args[], int argsc, Redirection *redir)
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
            perror("fork");
        }
        else if (rc == 0) {
            //printf("Child (pid: %d)\n", getpid());
            int redir_status = apply_redirection(redir);
            if (redir_status < 0) {
                _exit(EXIT_FAILURE);
            }
            else {
                child(args, argsc);
            }
        }
        else {
            //printf("Parent (pid: %d)\n", getpid());
        }
    }

    ///Handle the 'exit' command;
    ///so that the shell, not the child process,
    ///exits.
}

/// (Add additional Advait / Person 1 functions below)

int parse_redirection(char *args[], int *argsc, Redirection *redir) {
    redir->filename = NULL;
    redir->type = REDIR_NONE;

    int num_redir_tokens_seen = 0;
    int redir_index = -1;

    int comp_output = 0;
    int comp_input = 0;
    int comp_append = 0;

    for (int i = 0; i < *argsc; i++) {
        comp_output = strcmp(">", args[i]);
        comp_input = strcmp("<", args[i]);
        comp_append = strcmp(">>", args[i]);

        if (comp_output == 0 || comp_input == 0 || comp_append == 0) {
            if (i + 1 >= *argsc) { // no filename given
                redir->type = REDIR_NONE;
                redir->filename = NULL;
                fprintf(stderr, "missing redirection filename \n");
                return -1;
            }
            else if (strcmp(">", args[i + 1]) == 0 || strcmp("<", args[i + 1]) == 0 || strcmp(">>", args[i + 1]) == 0) {
                redir->type = REDIR_NONE;
                redir->filename = NULL;
                fprintf(stderr, "cannot provide redirection operator as filename \n");
                return -1;
            }
            else {
                if (comp_output == 0) redir->type = REDIR_OUTPUT;
                else if (comp_input == 0) redir->type = REDIR_INPUT;
                else if (comp_append == 0) redir->type = REDIR_APPEND;
                redir->filename = args[i + 1];
                redir_index = i;
                num_redir_tokens_seen++;
            }
        }
    }

    if (num_redir_tokens_seen > 1) {
        redir->type = REDIR_NONE;
        redir->filename = NULL;
        fprintf(stderr, "multiple redirection tokens \n");
        return -1;
    }

    if (redir_index > -1) {
        for (int j = redir_index; j + 2 < *argsc; j++) {
            args[j] = args[j + 2];
        }
        *argsc -= 2;
        args[*argsc] = NULL;
    }

    return 0;
}


int apply_redirection(const Redirection *redir) {
    int fd;
    if (redir->type == REDIR_INPUT) { // <
        fd = open(redir->filename, O_RDONLY);
    }
    else if (redir->type == REDIR_OUTPUT) { // >
        fd = open(redir->filename, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    }
    else if (redir->type == REDIR_APPEND) { // >>
        fd = open(redir->filename, O_WRONLY | O_CREAT | O_APPEND, 0644);
    }
    else if (redir->type == REDIR_NONE) {
        return 0;
    }
    else {
        perror("invalid redir type");
        return -1;
    }


    if (fd < 0) {
        perror("open failed");
        return -1;
    }

    int dup_status;
    if (redir->type == REDIR_INPUT) {
        dup_status = dup2(fd, STDIN_FILENO);
    }
    else {
        dup_status = dup2(fd, STDOUT_FILENO);
    }

    if (dup_status < 0) perror("redirect failed");

    close(fd);
    // input redir returns 0 on success, but output redir returns 1
    // so need to map so that error/success output consistent regardless of redir type
    return (dup_status <  0) ? -1 : 0;
}


/*

int pipefd[2];
int status = pipe(pipefd);
status = 0 -> successful (-1 -> fail)
pipefd[0] -> read end
pipefd[1] -> write end


in each child use dup2 but connect write end to STDOUT_FILENO, and read end to STDIN_FILENO


*/


int parse_pipe(char *args[], int *argsc, char **commands[], int *num_commands) {
    *num_commands = 0; // ensuring its initialised
    if (*argsc == 0) return 0; // skip launching a process
    *num_commands = 1;
    commands[0] = &args[0];
    for (int i = 0; i < *argsc; i++) {
        if (strcmp(args[i], "|") == 0) {
            if (i == 0) {
                // invalid
                fprintf(stderr, "shell: malformed pipeline\n");
                return -1;
            }
            else if (i == *argsc - 1) {
                // invalid
                fprintf(stderr, "shell: malformed pipeline\n");
                return -1;
            }
            else if (strcmp(args[i + 1], "|") == 0) {
                // invalid
                fprintf(stderr, "shell: malformed pipeline\n");
                return -1;
            }
            commands[*num_commands] = &args[i + 1];
            (*num_commands)++;
        }
    }

    for (int i = 1; i < *num_commands; i++) {
        *(commands[i] - 1) = NULL;
    }

    return 0;
}


int count_args(char *args[]) {
    int n = 0;
    while (args[n] != NULL) {
        n++;
    }
    return n;
}


int launch_pipeline(char **commands[], int num_commands) {
    int prev_read_fd = -1;
    int pipefd[2];
    pid_t pids[MAX_ARGS];
    int launched = 0;
    int error = 0;

    for (int i = 0; i < num_commands; i++) {
        int is_last = (i == num_commands - 1);

        if (is_last == 0) {
            if (pipe(pipefd) == -1) {
                perror("pipe failed");
                // need to handle already-launched children
                error = -1;
                break;
            }
        }

        int rc = fork();

        if (rc == 0) { // child

            if (prev_read_fd != -1) {
                if (dup2(prev_read_fd, STDIN_FILENO) == -1) {
                    perror("connection to current stdin failed");
                    _exit(EXIT_FAILURE);
                }
            }

            if (is_last == 0) {
                if (dup2(pipefd[1], STDOUT_FILENO) == -1) {
                    perror("connection to current stdout failed");
                    _exit(EXIT_FAILURE);
                }
            }
            if (prev_read_fd != -1) { // not start
                close(prev_read_fd);
            }

            if (!is_last) {
                close(pipefd[0]);
                close(pipefd[1]);
            }
            
            child(commands[i], count_args(commands[i]));
            _exit(EXIT_FAILURE); // ensuring child cannot reenter
        }
        else if (rc > 0) { // parent
            pids[launched] = rc;
            launched++;

            if (prev_read_fd != -1) { // not start
                close(prev_read_fd);
            }

            if (is_last == 0) { // allowing for connection to be made across stages
            // pipefd[1] is the current stage output/write end
            // pipefd[0] will be passed to the next stage as its input/read end
                close(pipefd[1]);
                prev_read_fd = pipefd[0];
            }
            else {
                prev_read_fd = -1;
            }
        }
        else {
            perror("fork");
            
            if (is_last == 0) {
                // pipes may have been created but fork failed so need to close them
                close(pipefd[0]);
                close(pipefd[1]);
            }
            error = -1;
            break;
        }
    }

    if (error == -1) {
        if (prev_read_fd != -1) {
            close(prev_read_fd);
        }

        for (int j = 0; j < launched; j++) {
            kill(pids[j], SIGTERM);
        }
    }

    for (int i = 0; i < launched; i++) {
        if (waitpid(pids[i], NULL, 0) == -1) {
            perror("waitpid");
        }
    }

    return error;    
}
