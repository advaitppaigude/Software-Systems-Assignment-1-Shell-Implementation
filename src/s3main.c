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

    ///Shared REPL loop (Advait: redirection/pipes/execution | Srivathsan: lwd/cd/batches/subshells)
    while (1) {
        read_command_line(line, lwd);
        parse_batched_commands(line, batch_cmds, &batch_count);

        for (int i = 0; i < batch_count; i++){
            if (is_cd(batch_cmds[i])) {
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
    }
    return 0;
}
