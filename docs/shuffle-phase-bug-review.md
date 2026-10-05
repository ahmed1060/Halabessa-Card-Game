# Shuffle prompt, missing cards and skipped rounds — investigation

## Implementation follow-up (2026-10-05)

The later user decision supersedes independent bot voting: only real players
determine shuffle/rematch outcomes. The existing unanimity outcome is retained;
bots neither vote nor block completion. The hardcoded deadline is 10 seconds,
with unanswered humans recorded as No and late votes rejected.

Local implementation now includes one guarded legacy vote resolver, stale phase/
match-sequence checks, deck restoration validation, single dealer rotation, a
two-second cut-card reveal, and bounded human voting in both protocols. Results
retain scores with explicit Yes/No, accepted/waiting status and countdown. The
training entry offers Easy/Medium/Hard/Expert, with distinct legal-information
strategies. Non-training bot levels are randomly assigned and persisted by bot
identity; future rank matching is not yet implemented.

Regression coverage includes the original delayed-vote sequence, expired rematch
No, invalid deck preservation, bot strategy/hidden-hand independence, difficulty
serialization and short landscape rematch controls with safe-area insets. Live
UI/production build verification is a separate gate, not inferred from unit tests.
No accounts or game data were deleted.

Local verification gate: 287 Flutter tests passed; 84 backend/startup/build tests
passed; whole-project analyzer exited successfully with no errors (247 existing
warning/info notices remain). Three short landscape result layouts passed with
simulated safe-area insets. This is not physical-device or full live-match proof.

Investigated 2026-10-05 against commit 85c7e82d. No gameplay changes or deployment
made during this investigation. No live users/matches were changed.

## Confirmed findings

- Normal room creation still defaults to protocol 0; protocol 1 is opt-in via
  HALABESSA_SERVER_MATCHES. The production web workflow does not enable that flag.
- Before a human votes, BotBrain.decideShuffleVote chooses No with 80% probability.
  A single No triggers an immediate next round. Bots therefore dismiss a human's
  prompt, rather than waiting for the human's choice.
- _handleBotVotes holds the old state's votes across asynchronous delays and
  continues after a phase change. voteShuffle/GameEngine._vote accept out-of-phase
  votes. Its final shuffle completion branch does not verify phase/round/binding.
- _checkVoteCompletion, _handleBotVotes and repeated queued evaluations can all
  initiate the next round. startNewRound has neither a source-phase guard nor a
  transition identity/lock.
- The first transition restores 52 harvested cards and clears harvest. A later
  transition restores that now-empty harvest, increments round/dealer again, and
  creates an empty deck. Empty deals then look like skipped gameplay.
- _handleRoundEnd increments dealerIndex before shuffleVoting, then startNewRound
  increments it again: dealer/cutter rotation also skips a seat on this path.
- Cut-card reveal has no minimum dwell: legacy dealingFasha immediately calls
  dealInitialCards; protocol 1 advanceMatch does likewise. The UI renders
  cutLastCard only during dealingFasha, so this reveal can vanish between frames.
- Legacy dealInitialCards' delayed callback checks only phase, not room/round/deal
  identity. This is another stale-callback risk, separate from the reproduction.

## Local reproduction

A temporary Flutter diagnostic used a fake offline room, fake audio and simulated
time. Starting at round 3 shuffleVoting with a human No and a complete 52-card
harvest, it exercised the existing delayed bot handler through bindToMatch.
Observed state sequence:

    3:0:shuffleVoting
    4:52:preRoundCut
    4:52:preRoundCut (late bot vote writes)
    5:0:preRoundCut
    6:0:preRoundCut
    6:0:dealingFasha
    6:0:dealingCards

The diagnostic's assertions verified both the valid first restored deck and the
subsequent empty-deck extra round. It passed with gameplay timers disabled to
isolate voting. The temporary diagnostic was removed, rather than keeping a test
which treats the known broken behavior as the desired regression contract.
This does not claim every reported live occurrence has exactly the same trace.

## Fix plan (not implemented)

1. Bind votes and all delayed preparation callbacks to room, binding generation,
   round and phase occurrence. Reject late/nonparticipant/duplicate votes; stop
   stale bot work after each await. Centralize vote completion and permit one
   guarded next-round transition per source round. Rotate dealer exactly once.
2. Apply the user's rule to every human/bot voting flow: collect real-player
   choices first (all eligible humans or the visible deadline), then make bots
   follow the human majority. A tie uses a persisted random tie-break for that
   voting occurrence, so retries do not reroll. Bots cannot prematurely resolve
   a human choice. Preserve the existing overall vote-outcome rules unless the
   user separately changes them; bot majority-following is not automatically
   a change from unanimity to majority for the room's decision.
3. Give the shuffle prompt a visible bounded decision window/countdown and show
   accepted/waiting state. Add an explicit cut-card reveal duration, then deal/
   memory duration. Match client scheduling with server-enforced timing for
   protocol 1; do not solve this merely with an animation delay.
4. Validate restored decks contain exactly 52 unique cards before mutating round,
   clearing harvest or dealing. On invalid state, stop with a recoverable error;
   never advance empty rounds. Ensure no old memory/deal callback opens playing
   for a newer round.
5. Regression tests: delayed bot votes after Yes/No resolution; simultaneous
   completion requests; repeated RTDB echoes; human majority/tie/retry rules;
   dealer rotation; invalid harvest; reveal/memory deadlines; reconnect during
   choices. Test protocol 0, offline and protocol 1 separately.
6. Browser acceptance: finish several rounds with a guest plus three bots;
   leave shuffle unanswered to read it, exercise both choices, verify cut card,
   4-card table/hand deal, 52-card conservation, one round increment and results.
   Run analyzer and full Flutter/backend/rules suites before publishing.

No user/account reset is part of this repair.

## Added review: end-of-match Play Again prompt

Source review on the same commit; no rematch fix implemented.

- GameBoardScreen returns MatchResultView for both rematchVoting and matchOver.
  Its separate MatchChoicePanel rematch branch is therefore not the rendered
  end-game prompt. Fixing that unused branch would not fix the actual screen.
- Online results offer a Yes/Play Again action but no explicit No vote. Return
  Home invokes leaveMatch instead. Its departure semantics are not the same as
  recording a rematch refusal.
- Once the player's vote appears in rematchVotes, onReplay becomes null and the
  button disappears. MatchResultView shows no accepted-vote/waiting status, voter
  counts, countdown or refusal/expiry explanation. The accepted-request latch
  also disables the button while waiting, without such an explanation.
- Protocol 0 has no rematch decision deadline. Completion requires four votes
  or a No, so a human who never responds can leave the remaining players waiting.
- Legacy bots always vote Yes for rematch, ignoring human majority/tie rules.
  Their delayed votes also lack room/round/phase binding and can write into an
  obsolete voting session. VoteAction accepts duplicate/out-of-phase votes.
- Offline Play Again directly creates a new practice match instead of voting.
  That is a reasonable separate UX, but pending old bot callbacks must be
  cancelled/invalidated when the new match replaces the old one.
- Existing callback acknowledgement/retry guards and responsive results layout
  are already implemented; the deficiencies above are not fixed by those tests.
- The old choice-branch translation says Best of 3, while the actual restart
  resets the match scores. Do not promise a series unless series tracking exists.

Extend the repair plan with:

1. Keep a single results/rematch surface, with scores and rewards remaining
   visible. Show "Play again with this room?", Yes/No, the accepted choice,
   human vote counts, a visible deadline and clear final outcome. Preserve Home.
2. Bind the decision to the finished match sequence as well as room/round/phase;
   reject duplicates/stale callbacks. Resolve the session exactly once using
   the same human-majority-following bot policy as shuffle voting.
3. Make No, departure and timeout explicit lifecycle events with agreed outcomes;
   no indefinite wait and no silent new match. Keep results available afterwards.
4. On accepted rematch, start one fresh match with one dealer assignment and
   valid deck. Protocol-1 reward settlement must complete before discarding the
   finished reward record; retries must not credit rewards again. Offline replay
   cancels all prior-session delayed work.
5. Test actual GameBoardScreen routing, not only the isolated result widget:
   accepted Yes, No, unanswered human, human majority/tie, departure, rejection/
   retry, reconnect, delayed old votes and duplicate completion. Verify the
   results-to-next-match transition live, including short phone landscape/RTL.
