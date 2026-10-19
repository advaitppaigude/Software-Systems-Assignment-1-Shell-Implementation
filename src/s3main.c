#include "s3.h"

int main(int argc, char *argv[]){

    ///Stores the command line input
    char line[MAX_LINE];

    ///The last (previous) working directory 
    char lwd[MAX_PROMPT_LEN-6]; 

    init_lwd(lwd);///Implement this function: initializes lwd with the cwd (using getcwd)

    ///Stores pointers to command arguments.
    ///The first element of the array is the command name.
    char *args[MAX_ARGS];

    ///Stores the number of arguments
    int argsc;

    int redir_status;
    Redirection redir;

    //stores batched input commands
    char *batch_cmds[MAX_ARGS];
    int batch_count;

    // need real path to shell as this needs to be used for subshells
    char shell_path[MAX_LINE];
    if (realpath(argv[0], shell_path) == NULL) {
        strcpy(shell_path, argv[0]);
    }

    ///Shared REPL loop (Advait: redirection/pipes/execution | Srivathsan: lwd/cd/batches/subshells)
    while (1) {
        if (argc > 1) {
            strcpy(line, argv[1]); // Subshell mode: run command passed in argv[1]
        } else {
            read_command_line(line, lwd); // Normal interactive mode
        }

        parse_batched_commands(line, batch_cmds, &batch_count);

        for (int i = 0; i < batch_count; i++){
            if (is_subshell(batch_cmds[i])){
                launch_subshell(batch_cmds[i], shell_path);
                reap();
            }else if (is_cd(batch_cmds[i])) {
                parse_command(batch_cmds[i], args, &argsc);
                run_cd(args, argsc, lwd);
            }
            else {
                parse_command(batch_cmds[i], args, &argsc);

                redir_status = parse_redirection(args, &argsc, &redir);

                if (redir_status == 0) {
                    launch_program(args, argsc, &redir);
                    reap();
                }
            }
        }

        if (argc > 1) {
            break; // Subshell finishes after executing its command string once
        }
    }
    return 0;
}
