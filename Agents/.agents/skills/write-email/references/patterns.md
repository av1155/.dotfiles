# Patterns by Email Type

Skeletons, not templates. Adapt the shape; never ship the placeholder phrasing.

## Simple request

Target 50 to 125 words.

```
Subject: <what you need> by <when>

<Name>,

<The ask, in one sentence, with the deadline.>

<One or two sentences of only the context they need to act.>

<Reason the deadline exists.>

<Name>
```

## Multi-part request

Target under 400 words in the email. Everything else moves to an attached one-pager.

Email carries: the bottom line, the two or three asks that actually block you (numbered), the deadline with its reason, a pointer to the attachment, and an out.

One-pager carries: numbered items grouped by what it costs the recipient to answer. Cheap answers first, then things needing a document check, then things that route to someone else. Every item is one line with its reason as a trailing clause, written so the recipient can reply inline underneath.

Close the one-pager with a section naming what belongs to other people, so the recipient does not feel handed the whole pile.

## Follow-up on silence

Target under 75 words. Do not apologise for following up, do not open with "just checking in", do not restate the original email in full.

```
Subject: <original subject>

<Name>,

<One line naming what you are waiting on and what it is blocking.>

<A smaller ask than the original, or a deadline after which you proceed on an assumption.>

<Name>
```

Making the second ask smaller than the first is what unsticks these. "Even a yes or no on item 2 unblocks me this week" gets answered when the full list did not.

## Bad news or a problem you found

Lead with the problem and its impact. Do not bury it under context, and do not soften it into ambiguity. State what you are doing about it before you state what you need from them, so the message does not read as dumping.

```
Subject: <the problem>, <the effect>

<Name>,

<What is wrong, and what it means in practice.>

<What you have already done or will do.>

<What you need from them, if anything, and by when.>

<Name>
```

## Status update nobody asked for

Target under 100 words. Lead with the state, not the activity. "Shipping Thursday" beats "I have been working on the deployment pipeline". Include a blocker only when you want something done about it.

## Decision request

Name the decision, give the options with the tradeoff on each in one clause, state your recommendation, and give the date after which you proceed with the recommendation. A decision email without a default produces silence.

## Introduction or cold outreach

Lead with the specific reason you are writing to this person rather than anyone else. Then the ask, kept small enough to accept in one reply. Then one line of who you are. Under 125 words. Nobody reads paragraph two of an email from a stranger.

---

## Worked example

Same content, two shapes. The first is the failure mode this skill exists to prevent.

### Before, 118 words

> Hi Sarah,
>
> I hope this email finds you well. I wanted to reach out regarding the analytics migration project that we discussed in last week's planning meeting.
>
> So I have been going through the data warehouse schema in detail over the past few days, and after carefully reviewing all of the table definitions and cross-referencing them against the requirements document, I think I may have found what could potentially be an issue with how the events table is currently partitioned.
>
> Sorry to bother you with this, but I was just wondering if you might have some time at some point to take a look and let me know your thoughts?
>
> Thanks so much,
> Alex

Four problems. The ask appears in the last sentence. Three sentences of narration describe how the work was done. Hedges stack up ("I think I may have found what could potentially be"). The apology reframes a legitimate technical escalation as an imposition. There is no deadline and no reason.

### After, 61 words

> Subject: Events table partitioning blocks the migration
>
> Sarah,
>
> The events table is partitioned by ingest date, but the migration spec assumes event date. Backfilling would rewrite about 4TB.
>
> Can you confirm which one the downstream reports actually depend on? I need it by Wednesday to keep the cutover on schedule.
>
> If it is ingest date, I will scope the rewrite instead.
>
> Alex

The ask is in the subject and again in sentence one. The technical finding stands on its own without a description of the search that produced it. The deadline carries its reason. The last line gives Sarah a path that does not require her to solve the problem, only to answer.
