# Rummy — Official Rules

**Rummy — The Felt Table Edition** by WAJIHA.
Classic meld-building card game for 2–4 players (humans and bots), played over 3 rounds. Lowest deadwood wins the match.

---

## 1. Objective

Be the first player to meld all your cards ("go out") or hold the lowest deadwood when the shoe runs out. Deadwood is scored across 3 rounds; the player with the **lowest total deadwood** wins the match.

## 2. Setup

- One standard 52-card deck, no jokers.
- 2–4 seats at the table. Each seat is a human or a bot (pass-and-play supported).
- Each player is dealt **7 cards**, face down.
- The remaining cards form the **stock** (face down). The top stock card is turned over to start the **discard pile** (face up).

## 3. Turn order

- Seats play clockwise, starting with seat 1.
- Every turn has two parts: **draw** (take the top stock card, or take the top discard) and then **play** (optionally meld / lay off, then discard exactly one card to end the turn).
- A turn ends only when the player discards. There is no passing.

## 4. Legal moves

- **Draw from stock:** take the top face-down stock card into your hand.
- **Draw from discard:** take the top face-up discard into your hand (you may not take deeper discards).
- **Lay a meld:** play 3+ cards from your hand as a new meld (see §6).
- **Lay off:** add a single card from your hand to any meld on the table (yours or anyone's) if the result is still a valid meld.
- **Discard:** end your turn by placing exactly one hand card face-up on the discard pile.
- Going out: if your hand is empty after melding, laying off, or discarding, the round ends immediately.

## 5. Illegal moves

- Drawing when it is not your draw step (e.g. drawing twice in one turn).
- Taking any discard other than the top one.
- Laying a meld with fewer than 3 cards, or cards that do not form a valid set or run.
- Laying off a card that does not extend a meld legally.
- Discarding zero cards, or two or more cards, to end a turn.
- Ending your turn without discarding (except by going out).
- Reordering or touching another player's hand.

## 6. Captures

There are no captures in Rummy. Taking the top discard is sometimes called "picking up", never capturing.

## 7. Special rules

- **Ace is low only.** A–2–3 is a valid run; Q–K–A and K–A–2 are not ("no round-the-corner").
- **Sets** must be 3–4 cards of the same rank in **distinct suits** (e.g. 7♠ 7♥ 7♦). A 5-card "set" is impossible — there are only 4 suits.
- **Runs** must be 3+ cards of consecutive ranks in the same suit (e.g. 4♥ 5♥ 6♥ 7♥).
- **Reshuffle:** if the stock runs out mid-round, the discard pile (except its top card) is shuffled to form a new stock.
- **Lay-offs** may extend any player's meld, including sequences at either end and sets up to 4 cards.

## 8. Scoring

When a round ends, every player except the round winner scores **deadwood** = the value of the cards left in their hand:

- Ace = **15**
- Face cards (J, Q, K) = **10**
- Number cards = face value (2–10)

Deadwood accumulates across the match. The round winner scores 0 for that round.

## 9. Winning conditions

- **Round:** a player goes out (empties their hand), or holds the lowest deadwood when the shoe is exhausted.
- **Match:** after 3 rounds, the player with the **lowest total deadwood** wins. Ties are broken by most round wins, then by lowest seat index.

## 10. Draw conditions

- If the stock is empty AND the discard pile has no drawable card (both exhausted), the round ends immediately and the player with the lowest hand deadwood takes the round. (The engine scores this automatically — the game never freezes.)
- A full match cannot end in a draw: tie-breaks (§9) always name a winner.

## 11. AI strategy

Three difficulties:

- **Easy:** draws the top discard only 60% of the time when it helps; discards the highest-deadwood card but blunders randomly 25% of the time; never considers what opponents might want.
- **Medium:** always takes a helpful discard; avoids discarding cards adjacent in rank/suit to the last three discards (doesn't feed opponents); melds whenever possible.
- **Hard:** everything Medium does, plus: values keeping flexible cards (multi-use) 15% more, grabs high-value discards to cut deadwood when behind, and lays off aggressively onto every meld.

All bots lay every meld they can find (sets first, then runs), lay off spare cards, and never stall: an engine watchdog force-completes any bot turn that runs long.

## 12. Edge cases

- **Going out on the first turn:** legal — a 7-card opening hand that melds fully wins the round immediately.
- **Meld then out:** if laying a meld empties the hand, the player goes out without discarding.
- **Lay-off then out:** same — emptying the hand by lay-off wins immediately.
- **Discard then out:** discarding your last card wins immediately.
- **Reshuffle with 1 discard:** the single top discard stays; the new stock is empty. The next draw attempt from the empty stock ends the round (§10).
- **All bots:** not allowed — at least one seat must be human.
- **Interruption (call, backgrounding):** the engine pauses its timers and the audio pauses; both resume exactly where they left off.

## 13. Test cases

1. Deal: every seat holds exactly 7 cards; stock = 52 − 7×seats; 1 discard.
2. Draw step: human cannot act before drawing; Draw/Meld/Discard buttons are disabled appropriately.
3. Meld validation: 7♠ 7♥ 7♦ accepted; 7♠ 7♠ 7♥ rejected; 4♥ 5♥ 6♥ accepted; Q♠ K♠ A♠ rejected; A♣ 2♣ 3♣ accepted.
4. Lay-off: 8♥ onto 4♥ 5♥ 6♥ 7♥ accepted; 8♠ onto the same run rejected; 7♣ onto 7♠ 7♥ 7♦ accepted; 7♠ duplicate rejected.
5. Go out by discard: hand empties → round-end dialog names the winner; deadwood of others added to scores.
6. Stock exhaustion: with 1 discard left and empty stock, drawing from stock ends the round via lowest deadwood (no freeze).
7. Bot turn: completes within ~5s with visible draw → meld → discard narration; watchdog recovers a stalled bot.
8. Scoring: A=15, K=10, 5=5 — e.g. A♠ K♥ 5♦ = 30 deadwood.
9. Match: after 3 rounds the lowest total deadwood wins; Play Again resets scores and round counter.
10. Persistence: rename players → force-close → names restored in order on all 4 slots.

---

*This document is the authoritative source of truth. If the implementation conflicts with it, fix the implementation.*
