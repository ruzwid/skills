# skills

Personal agent skills.

## Skills

### `create-bounce-pr`

End-to-end PR creation for Bounce Insights repos. You give it a Jira ticket key; it commits (with approval), pushes, and opens review-tool-formatted PRs across every affected repo.

#### Install
```
npx skills add ruzwid/skills --skill create-bounce-pr -g
```

#### Update
```
npx skills update
```

#### How it works

You've got a Jira ticket (e.g. `BOUN-2322`) and some code to ship.

1. **Pick up the ticket.** Create it in Jira, or grab one assigned to you.
2. **Checkout the branch** in each repo you'll touch:
   ```bash
   cd ~/bounce/<repo>
   git checkout master && git pull
   git checkout -b BOUN-2322
   ```
3. **Write the code.** Agent, your hands, pair programming — doesn't matter.
4. **Run the skill**, passing the ticket code:
   ```
   /create-bounce-pr BOUN-2322
   ```
5. **Approve the commit(s).** The skill shows what will be committed (flagging anything that doesn't look related to the ticket) and uses `[BOUN-2322] - <Jira summary>` as the message.
6. **Get PR URLs back.** The skill pushes, builds the review-tool-formatted description (Changes, Testing, Repositories to Review, Functionality Review), opens the main PR + any secondary PRs, and prints the links.

Want just the markdown? Ask for *"the PR description for BOUN-2322"* — it'll generate the body and skip commit/push/PR creation. No `gh` or `jira` CLI required in that mode.
