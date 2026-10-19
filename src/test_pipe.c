#include "s3.h"
#include <stdio.h>
#include <string.h>

int main(void)
{
    char lines[9][100] = {
        "echo hello",
        "echo hello | wc -c",
        "echo hello | tr a-z A-Z | wc -c",
        "echo hello |",
        "| wc -c",
        "echo | | wc",
        "seq 1 100000 | wc -l",
        "echo hello | cat",
        ""
    };

    for (int l = 0; l < 9; l++) {
        char *args[MAX_ARGS];
        int argsc = 0;

        char **commands[MAX_ARGS];
        int num_commands = 0;

        printf("Input: \"%s\"\n", lines[l]);

        parse_command(lines[l], args, &argsc);

        int status = parse_pipe(args, &argsc, commands, &num_commands);

        if (status == -1) {
            printf("Parsing failed\n\n");
            continue;
        }

        if (status == 0 && num_commands == 2) {
            int result = launch_pipeline(commands, num_commands);

            printf("Pipeline result: %d\n", result);
        }

        printf("\n");
    }

    return 0;
}