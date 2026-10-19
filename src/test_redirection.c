#include "s3.h"

int main(void)
{
    char lines[7][100];
    strcpy(lines[0], "echo > output.txt hello");
    strcpy(lines[1], "echo hello >> out.txt");
    strcpy(lines[2], "sort < input.txt");
    strcpy(lines[3], "echo hello >");
    strcpy(lines[4], "echo hello > <");
    strcpy(lines[5], "echo hello > a.txt > b.txt");
    strcpy(lines[6], "echo hello");

    for (int l = 0; l < 7; l++) {
        char *line = lines[l];
        char *args[MAX_ARGS];
        int argsc;
        Redirection redir;

        parse_command(line, args, &argsc);

        int status;
        // TODO: Call parse_redirection().
        status = parse_redirection(args, &argsc, &redir);

        // TODO: Print the return status.
        printf("Redirect status: %d \n", status);

        // TODO: Print redir.type and redir.filename.
        printf("%d ", redir.type);
        printf("\n");
        printf("%s ", redir.filename);
        printf("\n");

        // TODO: Print the updated argument count.
        printf("%d", argsc);
        printf("\n");

        // TODO: Loop through args and print each argument.
        for (int i = 0; i <= argsc; i++) {
            printf("%s ", args[i]);
        }
        printf("\n\n\n");
    }

    return 0;
}