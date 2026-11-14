#include "s3.h"
static char history[MAX_HISTORY][MAX_LINE];
static int counter = 0;
/// ===========================================================================
/// PERSON 2 (Srivathsan): Prompt & cd (Sec 3), Batched Commands (Sec 5), Subshells (Sec 6-7)
/// ===========================================================================

void construct_shell_prompt(char shell_prompt[], char lwd[]){
    // get current working directory to display in shell 
    char cwd[MAX_PATH_LEN]; 
    if (getcwd(cwd, sizeof(cwd)) == NULL) {
        strcpy(cwd, lwd);
    }
    // check if command is being entered by user or by script
    if (isatty(STDIN_FILENO) == 0){ // if a script is entering the command then keep simple prompt style
        snprintf(shell_prompt, MAX_PROMPT_LEN, "[%s s3]$ ", cwd);
    }else{ // show custom prompt when user is using shell
        char *user = getenv("USER");
        char *home = getenv("HOME");
        char display_cwd[MAX_PATH_LEN];

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

static struct termios orig_term; // stores terminal attributes used for up/down arrow and tab
static struct termios raw_term;

///Handles Up/Down arrow ANSI escape sequences to navigate command history
static void handle_history_arrows(char line[], int *len, int *hist_idx, const char shell_prompt[]){
    int d = getchar();
    if (d == '['){
        int e = getchar();
        if ((e == 'A') && (*hist_idx > 0)){ // up arrow go to previous command
            (*hist_idx)--;
            strcpy(line, history[*hist_idx]);
            *len = strlen(line);
            printf("\r\033[K%s%s", shell_prompt, line); //output command
        }else if ((e == 'B') && (*hist_idx < counter)){ // down arrow go to next command
            (*hist_idx)++;
            if (*hist_idx == counter){ // no next commands just output empty string
                line[0] = '\0';
                *len = 0;
            }else{
                strcpy(line, history[*hist_idx]);
                *len = strlen(line);
            }
            printf("\r\033[K%s%s", shell_prompt, line); // output command
        }
    }
}

///Applies a single Tab match inline or prints multiple matches and redraws the prompt
static void apply_tab_matches(char line[], int *len, int start, const char shell_prompt[], const char * const matches[], size_t count){
    if (count == 0){
        return;
    }
    if (count == 1){ // single match: complete word inline
        if ((size_t)start + strlen(matches[0]) < (size_t)MAX_LINE){
            strcpy(&line[start], matches[0]);
            *len = strlen(line);
        }
    }else{ // multiple matches: list all candidates on a new line
        putchar('\n');
        for (size_t i = 0; i < count; i++){
            printf("%s ", matches[i]);
        }
        putchar('\n');
    }
    printf("\r\033[K%s%s", shell_prompt, line);
}

///Handles Tab completion for the current word under the cursor
static void handle_tab_completion(char line[], int *len, const char shell_prompt[]){
    int start = *len; // start from the back
    while (start > 0 && line[start - 1] != ' '){ // grab the start index of the latest word
        start--;
    }
    if (start < *len){
        //command search 
        int prev = start - 1;
        while (prev >= 0 && line[prev] == ' '){
            prev--;
        }
        if ((prev < 0 || line[prev] == ';' || line[prev] == '|' || line[prev] == '(') && (strchr(&line[start], '/') == NULL)){
            static const char *commands[] = {
                "cal", "cat", "cd", "chmod", "clear", "cp", "date", "echo",
                "exit", "gcc", "grep", "head", "less", "ls", "man", "mkdir",
                "ps", "pwd", "sort", "tac", "touch", "tr", "uniq", "wc", "whoami"
            };
            size_t num_cmds = sizeof(commands) / sizeof(commands[0]);
            size_t prefix_len = strlen(&line[start]);
            const char *matches[32];
            size_t match_count = 0;

            for (size_t i = 0; i < num_cmds; i++){
                if (strncmp(commands[i], &line[start], prefix_len) == 0){
                    matches[match_count++] = commands[i];
                }
            }

            apply_tab_matches(line, len, start, shell_prompt, matches, match_count);
        }else{
            // glob to find matching file/folder names for the word typed
            char pattern[MAX_LINE];
            snprintf(pattern, sizeof(pattern), "%s*", &line[start]);
            glob_t tab_results;
            if (glob(pattern, 0, NULL, &tab_results) == 0){
                apply_tab_matches(line, len, start, shell_prompt, (const char * const *)tab_results.gl_pathv, tab_results.gl_pathc);
                globfree(&tab_results); // release glob
            }
        }
    }
}

///Prints a shell prompt and reads input from the user
void read_command_line(char line[], char lwd[]){
    char shell_prompt[MAX_PROMPT_LEN];
    construct_shell_prompt(shell_prompt, lwd); // build shell prompt string
    printf("%s", shell_prompt);

    if (isatty(STDIN_FILENO) == 0){ // check if a script is using shell or user
        if (fgets(line, MAX_LINE, stdin) == NULL){ // use legacy method for scripts/pipes
            if (feof(stdin)){
                exit(0);
            }
            perror("fgets failed");
            exit(1);
        }
        ///Remove newline (enter)
        size_t n = strlen(line);
        if (n > 0 && line[n - 1] == '\n'){
            line[n - 1] = '\0';
        }
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
            if (c == EOF || c == 4){ // handle Ctrl+D or EOF
                if (c == EOF || len == 0){
                    tcsetattr(STDIN_FILENO, TCSANOW, &orig_term); // restore previous terminal attributes
                    putchar('\n');
                    exit(0);
                }
            }else if (c == '\n'){ //user presses enter to start new command
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
                handle_history_arrows(line, &len, &hist_idx, shell_prompt);
            }else if (c == '\t'){ // tab entered try to complete command
                handle_tab_completion(line, &len, shell_prompt);
            }else{ // normal ASCII character entered so display it 
                if (len < MAX_LINE -1){
                    line[len++] = c;
                    line[len] = '\0';
                    putchar(c);
                }
            }
        }
        tcsetattr(STDIN_FILENO, TCSANOW, &orig_term); // restore previous terminal attributes
    }
    add_to_history(line); // append current command to history
}

void parse_command(char line[], char *args[], int *argsc){
    ///Tokenizes line in-place (space delimited, preserving text inside "..." or '...')
    int i = 0;
    *argsc = 0;
    while (line[i] != '\0' && *argsc < MAX_ARGS - 1){ 
        while (line[i] == ' '){ // skip leading space
            i++;
        }
        if (line[i] == '\0'){
            break;
        }
        if (line[i] == '"' || line[i] == '\''){
            char quote = line[i++];
            args[(*argsc)++] = &line[i];
            while (line[i] != '\0' && line[i] != quote){
                i++;
            }
            if (line[i] == quote){
                line[i++] = '\0';
            }
        }else{
            args[(*argsc)++] = &line[i];
            while (line[i] != '\0' && line[i] != ' '){
                i++;
            }
            if (line[i] == ' '){
                line[i++] = '\0';
            }
        }
    }

    args[*argsc] = NULL; ///args must be null terminated

    expand_globs(args, argsc); 
}

void init_lwd(char lwd[]){
    if (getcwd(lwd, MAX_PATH_LEN) == NULL){ //writes getcwd to lwd
        perror("getcwd failed");
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
    char temp[MAX_PATH_LEN];
    int have_cwd = (getcwd(temp, sizeof(temp)) != NULL);

    int rc;
    // Situation 1: cd (change to home directory)
    if ((argsc == 1) && (args[1] == NULL)){
        char *home = getenv("HOME");
        if (home == NULL){
            fprintf(stderr, "cd: HOME not set\n");
            return;
        }
        rc = chdir(home);
    } else if ((argsc == 2) && strcmp(args[1], "-") == 0){
        // Situation 2: cd - (go back to previous lwd)
        rc = chdir(lwd);
    } else {
        // Situation 3 & 4: cd .. or cd <folder>
        rc = chdir(args[1]);
    }

    // Only update lwd if chdir succeeded (returned 0)
    if (rc == 0) {
        if (have_cwd) {
            strcpy(lwd, temp);
        }
    } else {
        perror("cd failed");
    }
}

/// Splits line in-place on delim only outside quotes and subshell parentheses
static void split_top_level(char line[], char delim, char *parts[], int *count){
    int i = 0;
    int shell_depth = 0;
    int in_single = 0;
    int in_double = 0;

    *count = 0;
    parts[(*count)++] = &line[0];

    while (line[i] != '\0') {
        if (line[i] == '\'' && !in_double) {
            in_single = !in_single;
        } else if (line[i] == '"' && !in_single) {
            in_double = !in_double;
        } else if (!in_single && !in_double) {
            if (line[i] == '(') {
                shell_depth++;
            } else if (line[i] == ')' && shell_depth > 0) {
                shell_depth--;
            } else if (line[i] == delim && shell_depth == 0 && *count < MAX_ARGS - 1) {
                line[i] = '\0';
                parts[(*count)++] = &line[i + 1];
            }
        }
        i++;
    }
    parts[*count] = NULL;
}

void parse_batched_commands(char line[], char *batch_cmds[], int *batch_count){
    split_top_level(line, ';', batch_cmds, batch_count);
}

int is_subshell(char line[]){
    int start, end;
    return find_subshell_bounds(line, &start, &end);
}

/// Parses `(inner) [redir]` into subshell argv and redirection.
/// Returns 1 if valid subshell, 0 if not a subshell, or -1 on invalid trailing tokens/redirection.
static int prepare_subshell_command(char line[], char shell_path[], char *sub_args[3], Redirection *redir){
    int start, end;
    if (!find_subshell_bounds(line, &start, &end)){
        return 0;
    }
    line[end] = '\0'; // replace closing ')' with '\0'
    sub_args[0] = shell_path;
    sub_args[1] = &line[start + 1];
    sub_args[2] = NULL;
    redir->type = REDIR_NONE;
    redir->filename = NULL;

    char *trail_args[MAX_ARGS];
    int trail_argsc = 0;
    parse_command(&line[end + 1], trail_args, &trail_argsc);
    if (trail_argsc > 0){
        if (parse_redirection(trail_args, &trail_argsc, redir) < 0 || trail_argsc > 0){
            return -1;
        }
    }
    return 1;
}

void launch_subshell(char line[], char shell_path[]){
    char *sub_args[3];
    Redirection redir;
    if (prepare_subshell_command(line, shell_path, sub_args, &redir) == 1){
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
    static char *glob_allocs[MAX_ARGS];
    static int glob_alloc_count = 0;
    for (int i = 0; i < glob_alloc_count; i++) {
        free(glob_allocs[i]);
    }
    glob_alloc_count = 0;

    // create new copy of args and argsc to store glob outputs
    char *new_args[MAX_ARGS];
    int new_argsc = 0;
    for (int i = 0; i < *argsc && new_argsc < MAX_ARGS - 1; i++){ // loop through each token
        glob_t results;
        if (strchr(args[i], '*') != NULL || strchr(args[i], '?') != NULL){ // if * or ? is found
            if (glob(args[i], GLOB_NOCHECK, NULL, &results) == 0){ // use glob() function
                for (size_t j = 0; j < results.gl_pathc && new_argsc < MAX_ARGS - 1; j++){
                    char *dup = strdup(results.gl_pathv[j]);
                    if (dup != NULL) {
                        glob_allocs[glob_alloc_count++] = dup;
                        new_args[new_argsc++] = dup; // append args with glob results
                    }
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
    (void)argsc;
    ///Replace child process image with the target command binary
    execvp(args[ARG_PROGNAME], args);
    // wont reach the code below if execvp successful
    perror("execvp");
    _exit(EXIT_FAILURE);
}

void launch_program(char *args[], int argsc, Redirection *redir)
{
    if (args[ARG_PROGNAME] == NULL) {
        return;
    }
    else {
        ///Handle 'exit' in parent shell so the shell itself exits
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
}

int parse_redirection(char *args[], int *argsc, Redirection *redir) {
    redir->filename = NULL;
    redir->type = REDIR_NONE;

    int num_redir_tokens_seen = 0;
    int redir_index = -1;

    for (int i = 0; i < *argsc; i++) {
        int comp_output = strcmp(">", args[i]);
        int comp_input = strcmp("<", args[i]);
        int comp_append = strcmp(">>", args[i]);

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

int parse_pipe_stages(char line[], char *pipe_stages[], int *num_stages) {
    *num_stages = 0;

    int k = 0;
    while (line[k] == ' ') k++;
    if (line[k] == '\0') {
        return 0;
    }

    split_top_level(line, '|', pipe_stages, num_stages);

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

/// Wires pipe descriptors and executes a single pipeline stage in the child process.
static void run_pipeline_child(char *stage, int prev_read_fd, int pipefd[2], int is_last, char shell_path[]) {
    if (prev_read_fd != -1) {
        if (dup2(prev_read_fd, STDIN_FILENO) == -1) {
            perror("connection to current stdin failed");
            _exit(EXIT_FAILURE);
        }
        close(prev_read_fd);
    }

    if (!is_last) {
        if (dup2(pipefd[1], STDOUT_FILENO) == -1) {
            perror("connection to current stdout failed");
            _exit(EXIT_FAILURE);
        }
        close(pipefd[0]);
        close(pipefd[1]);
    }

    char *sub_args[3];
    Redirection stage_redir;
    int sub_rc = prepare_subshell_command(stage, shell_path, sub_args, &stage_redir);
    if (sub_rc < 0) {
        _exit(EXIT_FAILURE);
    } else if (sub_rc == 1) {
        if (apply_redirection(&stage_redir) < 0) {
            _exit(EXIT_FAILURE);
        }
        child(sub_args, 2);
    } else {
        char *stage_args[MAX_ARGS];
        int stage_argsc = 0;
        parse_command(stage, stage_args, &stage_argsc);
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

int launch_pipeline_stages(char *pipe_stages[], int num_stages, char shell_path[]) {
    int prev_read_fd = -1;
    int pipefd[2];
    pid_t pids[MAX_ARGS];
    int launched = 0;
    int error = 0;

    for (int i = 0; i < num_stages; i++) {
        int is_last = (i == num_stages - 1);

        if (!is_last && pipe(pipefd) == -1) {
            perror("pipe failed");
            error = -1;
            break;
        }

        int rc = fork();
        if (rc == 0) {
            run_pipeline_child(pipe_stages[i], prev_read_fd, pipefd, is_last, shell_path);
        } else if (rc > 0) {
            pids[launched++] = rc;
            if (prev_read_fd != -1) {
                close(prev_read_fd);
            }
            if (!is_last) {
                close(pipefd[1]);
                prev_read_fd = pipefd[0];
            } else {
                prev_read_fd = -1;
            }
        } else {
            perror("fork");
            if (!is_last) {
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
