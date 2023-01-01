# jeff

[![Build](https://circleci.com/gh/mtlynch/jeff.svg?style=shield)](https://circleci.com/gh/mtlynch/jeff)
[![GoDoc](https://godoc.org/github.com/mtlynch/jeff?status.svg)](https://godoc.org/github.com/mtlynch/jeff)
[![Go Report Card](https://goreportcard.com/badge/github.com/mtlynch/jeff)](https://goreportcard.com/report/github.com/mtlynch/jeff)
[![License](https://img.shields.io/badge/license-BSD--3--Clause-5B74AD.svg)](https://github.com/mtlynch/jeff/blob/master/LICENSE)


A tool for managing login sessions in Go.

## Motivation

I was looking for a simple session management wrapper for Go and from what I
could tell there exists no simple sesssion library.

This library is requires a stateful backend to enable easy session revocation
and simplify the security considerations.  See the section on security for more
details.

## Features

- Redirect to login
- Middleware wrapper
- Easy to clear sessions
- Small, idiomatic API
- CSRF Protection
- Context aware
- Fast
- Multiple sessions under one key

## Requirements

The module uses msgpack for encoding and requires a recent version of Go to
function.  It's recommended to have a version no older than 1 year, but
there's a hard requirement to have at least Go 1.11+.  Tests are only done
against the latest stable version of Go.

## Usage

There are three primary methods:

Set starts the session, sets the cookie on the given response, and stores the
session token.

```go
func (s Server) Login(w http.ResponseWriter, r *http.Request) {
    user = Authenticate(r)
    if user != nil {
        // Key must be unique to one user among all users
        err := s.jeff.Set(r.Context(), w, user.Email)
        // handle error
    }
    // finish login
}
```

Wrap authenticates every http.Handler it wraps, or redirects if authentication
fails.  Wrap's signature works with [alice](https://github.com/justinas/alice).
The "Public" wrapper checks for an active session but _does not_ call the
redirect handler if there is no active session.  It's a way to set the active
session on the request without denying access to anonymous users.

```go
    mux.HandleFunc("/login", loginHandler)
    mux.HandleFunc("/products", j.Public(productHandler))
    mux.HandleFunc("/users", j.Wrap(usersHandler))
    http.ListenAndServe(":8080", mux)
```

Clear deletes the active session from the store for the given key.

```go
func (s Server) Revoke(w http.ResponseWriter, r *http.Request) {
    // stuff to get user: admin input form or perhaps even from current session
    err = s.jeff.Clear(r.Context(), user.Email)
    // handle err
}
```

The default redirect handler redirects to root.  Override this behavior to set
your own login route.

```go
    sessions := jeff.New(store, jeff.Redirect(
        http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            http.Redirect(w, r, "/login", http.StatusFound)
        })))
```

This is primarily helpful to run custom logic on redirect:

```go
    // customHandler gets called when authentication fails
    sessions := jeff.New(store, jeff.Redirect(customHandler))
```

## Design

Session tokens are securely generated on `Set` (called after successful login).
This library is unique in that the user gets to decide the session key. This is
to make it easier for operators to manage sessions by not having to track/store
session tokens after creating a session. Session keys don't have to be
cryptographically secure, just unique per user.  A good key that works for
most people is the user's email.

The cookie format is as follows:

    CookieName=SessionKey::SessionToken

The SessionKey is used to find the given session in the backend. If found, the
client SessionToken is then constant-time compared with the stored token.

Sessions are stored in the backend as a map from the application-chosen session
key to a list of active sessions.  Sessions are lazily cleaned up once they
expire.

## Security

Most of the existing solutions use encrypted cookies for authentication. This
enables you to have stateless sessions.  However, this strategy has two major
drawbacks:

- Single ultra-secret key.
- Hard to revoke sessions.

It's possible to alleviate these concerns, but in the process one will end up
making a stateful framework for revocation, and a complicated key management
strategy for de-risking the single point of failure key.

Why aren't we encrypting the cookie?

Encrypting the cookie implies the single secret key used to encrypt said
cookie.  Programs like [chamber](https://github.com/segmentio/chamber) can aid
in handling these secrets, but any developer can tell you that accidentally
logging environment variables is commonplace.  I'd rather reduce the secrets
required for my service to a minimum.

### CSRF Protection

This library also provides limited CSRF protection via the SameSite session
cookie attribute.  This attribute (implemented in modern browsers) limits a
Cross Origin Request to a subset of safe HTTP methods.  See the [OWASP
Guide](https://www.owasp.org/index.php/SameSite) for more details.

## Development

Clone the repo, run `docker-compose up -d`, then run `make test`.

With the local redis instance running, you can then run the example
application:  `go run ./cmd/example/main.go`.

## Limitations

Also excluded from this library are flash sessions.  While useful, this is not
a concern for this library.  If you need this feature, please see one of the
libraries below.

### Race Conditions

There is a race condition inherant in how this library handles expiration and
deletion of sessions.  Because sessions are stored as a list for each user, to
add, delete, or prune sessions, it's required to do a read, modify, write
without any kind of transaction.  That means that it's possible, for example,
for a new session to be wiped out if it's created between reading and writing
in another concurrent read-modify-write operation, or for a session which was
meant to be cleared, didn't get cleared because the clear was issued during
another processes' modify step in the read-modify-write cycle.

In practice, this should be quite rare but for people considering this for
short-lived sessions with high numbers of concurrent sessions per user, you
might want to reconsider.



## Alternatives

The most popular session management tool is in the gorilla toolkit. It uses
encrypted cookies by default.  Has a very large API.

https://github.com/gorilla/sessions

A comprehensive session management tool.  Also a very large API.  Heavy use of
naked interfaces.

https://github.com/kataras/go-sessions

Encrypted cookie manager by default.  Has middleware feature.  Big API. No easy
way to clear session without storing session token elsewhere.

https://github.com/alexedwards/scs

Lightweight, server-only API.  Uncertain about what the purpose of the Manager
interface is.  Heavy use of naked interface.

https://github.com/icza/session

Lightweight, server-only API.  Includes concept of Users in library. No
wrapping or middleware.

https://github.com/rivo/sessions

Batteries-included middleware for keeping track of users, login states and
permissions.  Very large API.

https://github.com/xyproto/permissions2
