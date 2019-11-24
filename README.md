# GitHub Webhooks "Platform"

This repository contains the code for an experimental platform I've rolled out
to automate a bunch of things that I do as part of maintaining some open source
projects, that I want to stop doing.

## Goals

- **Simple** - this is hosted on a hobby dyno on Heroku - nothing fancy
- **Extensible** - web hooks come in, stuff happens, results appear on GitHub
  if needed
- **Boring** - no bleeding edge tech necessary, just a simple webapp with jobs
  infrastructure that should support being able to scale this later if needed

## Features

I currently have one job created that runs when a pull request event is raised
on [Up-For-Grabs](https://github.com/up-for-grabs/up-for-grabs.net) to review
any project file changes to ensure they are correct.

This is automating my experience reviewing PRs for the project, and it consists
of a few steps that are spread across a number of places:

- Can I parse the project file? If not, what needs to be addressed?
- Is the project hosted on GitHub? If so, does it still exist there?
- Did the user specify the right label? Is it in use on the project?
- Did the user specify a tag that should be normalized? What should it be
  normalized to?

So far I've been able to script and codify these checks to run whenever a
webhook matching the required criteria is received, and you can see it in action
here:

- [pull request demonstrating various warning stats](https://github.com/up-for-grabs/up-for-grabs.net/pull/1713)
- ["happy path" pull request](https://github.com/up-for-grabs/up-for-grabs.net/pull/1715)

I'll start fleshing things out once I've got a better baseline and more test
coverage, now that I've got the key pieces in place and this is working against
production data.

## Coming Soon™

- a dashboard interface to support tracing webhook activity (currently using
  the Heroku logs portal which is very noisy)
- investigate whether I can detect "PR is mergeable" from webhooks, so that I
  can auto-merge some PRs without needing human intervention
- investigate using pull request reviews API
- investigate using suggested changes to recommend fixes
- investigate applying this to other projects I maintain, and how that affects
  the overall architecture
