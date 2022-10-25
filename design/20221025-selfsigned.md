# Deprecating the SelfSigned Issuer

## Note on Terminology

This design talks about `Issuer` resources, but everything applies equally for `ClusterIssuers`.

## Summary

It's proposed that we deprecate the SelfSigned issuer but continue to support its use in the cases
we already support - for cert-manager CertificateRequests and k8s CertificateSigningRequests.

In its place, we add a new boolean `selfSigned` field for Certificate resources which is mututally
exclusive with an `issuerRef`.

## Motivation

### Part 1: It's Different

The SelfSigned issuer works in a fundamentally different way to all other issuers. When we use any
other issuer, we're asking the owner of some issuing certificate to use its private key to sign our
certificate request, and that issuer may choose to either honor that request and sign our request or
else to reject us and cause our request to fail.

Crucially, these issuers do not need access to our certificate's private key, and we don't need
access to the signing certificate's private key.

For SelfSigned, though, there's no private key for the issuer because there is no issuing CA.
We only need the private key for the cert we're trying to issue.

This difference means that a user wanting to use the SelfSigned issuer actually needs to do extra work
which they don't have to do otherwise; they need to annotate their `CertificateRequest` (or CSR) with
the location of the secret containing the private key for the certificate, since the issuer needs to
know where to access the key.

Put another way: the SelfSigned issuer alone requires additional configuration _at issuance time_
which no other issuer needs. This is unavoidable.

## Part 2: CSRs

cert-manager provides two certificate-related CRDs - `Certificate` and `CertificateRequest`.

Certificates are friendly - they're intentionally not perfect representations of actual X.509 certs,
in favour of them being easier to use. It's all YAML.

CertificateRequests are not friendly. They wrap encoded CSRs as specified by PKCS #10, and as such
are a pain to create. They require that the request is signed by the private key of the end-entity
certificate being issued.

Important, CSRs (the underlying PKCS #10 primitives) make no sense for a selfsigned certificate. If
you're self-signing, then you _already_ have the issuer's private key by definition, and you don't
need to "request" signing - you can just issue the certificate immediately.

Put another way: `CertificateRequest`s don't make sense for self signed certs. When the SelfSigned
issuer consumes them, it's because we treat CRs as an implementation detail.
