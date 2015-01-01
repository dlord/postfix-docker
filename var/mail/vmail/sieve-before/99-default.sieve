require ["envelope", "fileinto", "imap4flags", "regex"];

# Trash messages with improperly formed message IDs
if not header :regex "message-id" ".*@.*\\." {
    discard;
    stop;
}

# File low-level spam in spam bucket, and viruses in Infected folder
if anyof (header :contains "X-Spam-Level" "*****",
          header :contains "X-Virus-Status" "Infected") {
    if header :contains "X-Spam-Level" "*****" {
        fileinto "Junk";
        setflag "\\Seen";
    } else {
        fileinto "Infected";
    }
}
