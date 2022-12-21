require ["envelope", "fileinto", "imap4flags", "regex"];

# Trash messages with improperly formed message IDs
if not header :regex "message-id" ".*@.*\\." {
    discard;
    stop;
}

# File low-level spam in spam bucket, and viruses in Infected folder
if header :contains "X-Spam" "Yes" {
    fileinto :create "Junk";
    stop;
}

if header :contains "X-Virus-Status" "Infected" {
    fileinto :create "Infected";
    stop;
}
