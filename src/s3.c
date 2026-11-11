#include "s3.h"
static char history[MAX_HISTORY][MAX_LINE];
static int counter = 0;
/// ===========================================================================
/// PERSON 2 (Srivathsan): Prompt & cd (Sec 3), Batched Commands (Sec 5), Subshells (Sec 6-7)
/// ===========================================================================

///Simple for now, but will be expanded in a following section
void construct_shell_prompt(char shell_prompt[], char lwd[]){
    // get current working directory to display in shell 
    char cwd[256]; 
    if (getcwd(cwd, sizeof(cwd)) == NULL) {
        strcpy(cwd, lwd);
    }
    // check if command is being entered by user or by script
    if (isatty(STDIN_FILENO) == 0){ // if a script is entering the command then keep simple prompt style
        snprintf(shell_prompt, MAX_PROMPT_LEN, "[%s s3]$ ", cwd);
    }else{ // show custom prompt when user is using shell
        char *user = getenv("USER");
        char *home = getenv("HOME");
        char display_cwd[256];

        if (home != NULL){ // error handling for truncating home
            size_t home_len = strlen(home);
            if ((strncmp(cwd, home, home_len) == 0) && ((cwd[home_len] == '/') || (cwd[home_len] == '\0'))){ // find and replace home directory
                strcpy(display_cwd, "~");
                strcat(display_cwd, &cwd[home_len]);
            }else{
                strcpy(display_cwd, cwd);
            }
        }else{
            strcpy(display_cwd, cwd);
        }

        if (user == NULL){ // error handling for adding username
            user = "user";
        }

        char host[64];
        if(gethostname(host, sizeof(host)) < 0){ // error handling for hostname
            strcpy(host, "localhost");
        }
        // format custom prompt into shell_prompt buffer
        snprintf(shell_prompt, MAX_PROMPT_LEN, "\033[0;33m[\033[1;32m%s@%s\033[0m:\033[1;34m%s\033[0;33m s3]$\033[0m ", user, host, display_cwd);
    }
}

struct termios orig_term; // stores terminal attributes used for up/down arrow and tab
struct termios raw_term;
///Prints a shell prompt and reads input from the user
void read_command_line(char line[], char lwd[]){
    char shell_prompt[MAX_PROMPT_LEN];
    construct_shell_prompt(shell_prompt, lwd); // build shell prompt string
    printf("%s", shell_prompt);

    if (isatty(STDIN_FILENO) == 0){ // check if a script is using shell or user
        if (fgets(line, MAX_LINE, stdin) == NULL){ // use legacy method for scripts/pipes
            perror("fgets failed");
            exit(1);
        }
        ///Remove newline (enter)
        line[strlen(line) - 1] = '\0';
    }else{ 
        /// the user has entered a command 
        tcgetattr(STDIN_FILENO, &orig_term); // store terminal attributes before checking for arrow keys
        raw_term = orig_term;
        raw_term.c_lflag &= ~(ICANON | ECHO);
        tcsetattr(STDIN_FILENO, TCSANOW, &raw_term);
        int len = 0;
        int hist_idx = counter;
        line[0] = '\0';

        while (1){ // loop until user enters a command
            int c = getchar();
            if (c == '\n'){ //user presses enter to start new command
                line[len] = '\0';
                putchar('\n');
                break;
            }else if (c == 127 || c == '\b'){ // remove characters when backspace is entered
                if (len > 0){
                    len--;
                    line[len] = '\0';
                    printf("\b \b");
                }
            }else if (c == '\033'){ // arrow keys pressed 
                int d = getchar();
                if (d == '['){
                    int e = getchar();
                    if ((e == 'A') && (hist_idx > 0)){ // up arrow go to previous command
                        hist_idx--;
                        strcpy(line, history[hist_idx]);
                        len = strlen(line);
                        printf("\r\033[K%s%s", shell_prompt, line); //output command
                    }else if ((e == 'B') && (hist_idx < counter)){ // down arrow go to next command
                        hist_idx++;
                        if (hist_idx == counter){ // no next commands just output empty string
                            line[0] = '\0';
                            len = 0;
                        }else{
                            strcpy(line, history[hist_idx]);
                            len = strlen(line);
                        }

                        printf("\r\033[K%s%s", shell_prompt, line); // output command
                    }
                }
            }else if (c == '\t'){ // tab entered try to complete command
                int start = len; // start from the back 
                while (start > 0 && line[start - 1] != ' '){ // grab the start index of the latest word
                    start--;
                } 
                if (start < len){ // glob to find matching file/folder names for the word typed 
                    char pattern[MAX_LINE];
                    strcpy(pattern, &line[start]);
                    strcat(pattern, "*");
                    glob_t tab_results;
                    if (glob(pattern, 0, NULL, &tab_results) == 0){
                        if (tab_results.gl_pathc == 1){ // found complete word to update full command
                            strcpy(&line[start], tab_results.gl_pathv[0]);
                            len = strlen(line);
                        }else{ // found multiple matches to list all of them and let user continue typing current command 
                            putchar('\n');
                            for (size_t i = 0; i < tab_results.gl_pathc; i++){ 
                                printf("%s ", tab_results.gl_pathv[i]);
                            }
                            putchar('\n');
                        }
                        globfree(&tab_results); // release glob
                        printf("\r\033[K%s%s", shell_prompt, line); //update output
                    }
                }
            }else{ // normal ASCII character entered so display it 
                line[len++] = c;
                line[len] = '\0';
                putchar(c);
            }
        }
        tcsetattr(STDIN_FILENO, TCSANOW, &orig_term); // restore previous terminal attributes
    }
    add_to_history(line); // append current command to history
}

void parse_command(char line[], char *args[], int *argsc){
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

    expand_globs(args, argsc); 
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

void parse_batched_commands(char line[], char *batch_cmds[], int *batch_count){
    int i = 0;
    int shell_depth = 0; //tracks the need for subshells
    //initialisation of parameters
    *batch_count = 0;
    batch_cmds[(*batch_count)++] = &line[0];

    while (line[i] != '\0') { //looping until command terminates
        if (line[i] == '(') { //found subshell
            shell_depth++;
        } else if (line[i] == ')') { //end of subshell
            shell_depth--;
        } else if (line[i] == ';' && shell_depth == 0 && *batch_count < MAX_ARGS - 1) { //normal sec5 operation
            line[i] = '\0';
            batch_cmds[(*batch_count)++] = &line[i + 1]; // start of the next command
        }
        i++;
    }
    batch_cmds[*batch_count] = NULL; //terminate list
}

int is_subshell(char line[]){
   int start, end;
    return find_subshell_bounds(line, &start, &end);
}

void launch_subshell(char line[], char shell_path[]){
    
    int start, end;
    if (find_subshell_bounds(line, &start, &end)){
        line[end] = '\0'; // replace closing ')' with '\0'
        char *sub_args[3] = { shell_path, &line[start + 1], NULL };
        Redirection redir = { REDIR_NONE, NULL };

        char *trail_args[MAX_ARGS];
        int trail_argsc = 0;
        parse_command(&line[end + 1], trail_args, &trail_argsc);
        if (trail_argsc > 0) {
            if (parse_redirection(trail_args, &trail_argsc, &redir) < 0 || trail_argsc > 0) {
                return;
            }
        }

        launch_program(sub_args, 2, &redir);
    }
}

int find_subshell_bounds(char line[], int *start, int *end){
    ///get rid of starting and ending ()
    int i = 0; //getting rid of leading spaces
    while (line[i] == ' ') {
        i++;
    }

    if (line[i] != '('){ // no subshell
        return 0;
    }
    *start = i;
    int shell_depth = 0;
    while (line[i] != '\0') {
        if (line[i] == '(') {
            shell_depth++;
        } else if (line[i] == ')') {
            shell_depth--;
            if (shell_depth == 0) {
                int j = i + 1;
                while (line[j] == ' ') j++;
                if (line[j] != '\0' && line[j] != '>' && line[j] != '<') {
                    return 0; // Something like "| sort" follows ')', so not a standalone subshell!
                }
                *end = i;
                return 1;
            }
        }
        i++;
    }
    return 0;
}

void expand_globs(char *args[], int *argsc){
    // create new copy of args and argsc to store glob outputs
    char *new_args[MAX_ARGS];
    int new_argsc = 0;
    for (int i = 0; i < *argsc; i++){ // loop through each token
        glob_t results;
        if (strchr(args[i], '*') != NULL || strchr(args[i], '?') != NULL){ // if * or ? is found
            if (glob(args[i], GLOB_NOCHECK, NULL, &results) == 0){ // use glob() function
                for (size_t j = 0; j < results.gl_pathc; j++){
                    new_args[new_argsc++] = strdup(results.gl_pathv[j]); // append args with glob results
                }
                globfree(&results);
            }
        }else{
            new_args[new_argsc++] = args[i]; // if * or ? is not found then append the current token
        }
    }

    //update args and argsc 
    for (int i = 0; i < new_argsc; i++) { 
        args[i] = new_args[i];
    }
    *argsc = new_argsc;

    args[*argsc] = NULL;
}  

void add_to_history(char line[]){
    int i = 0; //getting rid of leading spaces
    while (line[i] == ' ') {
        i++;
    }
    // check if the first non-space character is not \0
    if (line[i] != '\0'){
        if (counter < MAX_HISTORY){
           strcpy(history[counter++], &line[i]);
        }
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
            int redir_status = apply_redirection(redir);
            if (redir_status < 0) {
                _exit(EXIT_FAILURE);
            }
            else {
                child(args, argsc);
            }
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

int parse_pipe_stages(char line[], char *pipe_stages[], int *num_stages) {
    int i = 0;
    int shell_depth = 0;
    *num_stages = 0;

    int k = 0;
    while (line[k] == ' ') k++;
    if (line[k] == '\0') {
        return 0;
    }

    pipe_stages[(*num_stages)++] = &line[0];

    while (line[i] != '\0') {
        if (line[i] == '(') {
            shell_depth++;
        } else if (line[i] == ')') {
            shell_depth--;
        } else if (line[i] == '|' && shell_depth == 0 && *num_stages < MAX_ARGS - 1) {
            line[i] = '\0';
            pipe_stages[(*num_stages)++] = &line[i + 1];
        }
        i++;
    }
    pipe_stages[*num_stages] = NULL;

    if (*num_stages > 1) {
        for (int s = 0; s < *num_stages; s++) {
            int idx = 0;
            while (pipe_stages[s][idx] == ' ') idx++;
            if (pipe_stages[s][idx] == '\0') {
                fprintf(stderr, "shell: malformed pipeline\n");
                return -1;
            }
        }
    }
    return 0;
}

int launch_pipeline_stages(char *pipe_stages[], int num_stages, char shell_path[]) {
    int prev_read_fd = -1;
    int pipefd[2];
    pid_t pids[MAX_ARGS];
    int launched = 0;
    int error = 0;

    for (int i = 0; i < num_stages; i++) {
        int is_last = (i == num_stages - 1);

        if (is_last == 0) {
            if (pipe(pipefd) == -1) {
                perror("pipe failed");
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
            if (prev_read_fd != -1) {
                close(prev_read_fd);
            }

            if (!is_last) {
                close(pipefd[0]);
                close(pipefd[1]);
            }

            int start, end;
            if (find_subshell_bounds(pipe_stages[i], &start, &end)) {
                pipe_stages[i][end] = '\0';
                char *trail_args[MAX_ARGS];
                int trail_argsc = 0;
                Redirection stage_redir = { REDIR_NONE, NULL };
                parse_command(&pipe_stages[i][end + 1], trail_args, &trail_argsc);
                if (trail_argsc > 0) {
                    if (parse_redirection(trail_args, &trail_argsc, &stage_redir) < 0 || trail_argsc > 0) {
                        _exit(EXIT_FAILURE);
                    }
                    if (apply_redirection(&stage_redir) < 0) {
                        _exit(EXIT_FAILURE);
                    }
                }
                char *sub_args[3] = { shell_path, &pipe_stages[i][start + 1], NULL };
                child(sub_args, 2);
            } else {
                char *stage_args[MAX_ARGS];
                int stage_argsc = 0;
                parse_command(pipe_stages[i], stage_args, &stage_argsc);
                Redirection stage_redir;
                if (parse_redirection(stage_args, &stage_argsc, &stage_redir) < 0) {
                    _exit(EXIT_FAILURE);
                }
                if (apply_redirection(&stage_redir) < 0) {
                    _exit(EXIT_FAILURE);
                }
                child(stage_args, stage_argsc);
            }
            _exit(EXIT_FAILURE);
        }
        else if (rc > 0) { // parent
            pids[launched] = rc;
            launched++;

            if (prev_read_fd != -1) {
                close(prev_read_fd);
            }

            if (is_last == 0) {
                close(pipefd[1]);
                prev_read_fd = pipefd[0];
            } else {
                prev_read_fd = -1;
            }
        }
        else {
            perror("fork");
            if (is_last == 0) {
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
