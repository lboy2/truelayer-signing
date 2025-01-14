require "minitest/autorun"
require "truelayer-signing"

CERTIFICATE_ID = "45fc75cf-5649-4134-84b3-192c2c78e990".freeze
PRIVATE_KEY = File.read(File.expand_path("../../test-resources/ec512-private.pem",
                                         File.dirname(__FILE__))).freeze
PUBLIC_KEY = File.read(File.expand_path("../../test-resources/ec512-public.pem",
                                        File.dirname(__FILE__))).freeze

TrueLayerSigning.certificate_id = CERTIFICATE_ID.freeze
TrueLayerSigning.private_key = PRIVATE_KEY.freeze

class TrueLayerSigningTest < Minitest::Test
  def test_full_request_signature_should_succeed
    body = { currency: "GBP", max_amount_in_minor: 50_000_00, name: "Foo???" }.to_json
    idempotency_key = "idemp-2076717c-9005-4811-a321-9e0787fa0382"
    path = "/merchant_accounts/a61acaef-ee05-4077-92f3-25543a11bd8d/sweeping"

    tl_signature = TrueLayerSigning.sign_with_pem
      .set_method(:post)
      .set_path(path)
      .add_header("Idempotency-Key", idempotency_key)
      .set_body(body)
      .sign

    result = TrueLayerSigning.verify_with_pem(PUBLIC_KEY)
      .set_method(:post)
      .set_path(path)
      .require_header("Idempotency-Key")
      .add_header("X-Whatever", "aoitbeh")
      .add_header("Idempotency-Key", idempotency_key)
      .set_body(body)
      .verify(tl_signature)

    refute(result.first.include?("\nX-Whatever: aoitbeh\n"))
    assert(result.first.include?("\nIdempotency-Key: " + idempotency_key + "\n"))
    assert(result.first
      .start_with?("POST /merchant_accounts/a61acaef-ee05-4077-92f3-25543a11bd8d/sweeping\n"))
  end

  def test_full_request_signature_without_headers_should_succeed
    body = { currency: "GBP", max_amount_in_minor: 50_000_00 }.to_json
    path = "/merchant_accounts/a61acaef-ee05-4077-92f3-25543a11bd8d/sweeping"

    tl_signature = TrueLayerSigning.sign_with_pem
      .set_method(:post)
      .set_path(path)
      .set_body(body)
      .sign

    result = TrueLayerSigning.verify_with_pem(PUBLIC_KEY)
      .set_method(:post)
      .set_path(path)
      .add_header("X-Whatever", "aoitbeh")
      .set_body(body)
      .verify(tl_signature)

    refute(result.first.include?("\nX-Whatever: aoitbeh\n"))
    refute(result.first.include?("\nIdempotency-Key: "))
  end

  def test_mismatched_signature_with_attached_valid_body_should_fail
    # Signature for `/bar` but with a valid jws-body pre-attached.
    # If we run a simple jws verify on this unchanged, it'll work!
    tl_signature = "eyJhbGciOiJFUzUxMiIsImtpZCI6IjQ1ZmM3NWNmLTU2ND" +
      "ktndeZnC04NGIzLTE5MmMyYzc4ZTk5MCIsInRsX3ZlcnNpb24iOiIyIiwidGxfaGV" +
      "hZGVycyI6IiJ9.UE9TVCAvYmFyCnt9.ARLa7Q5b8k5CIhfy1qrS-IkNqCDeE-VFRD" +
      "z7Lb0fXUMOi_Ktck-R7BHDMXFDzbI5TyaxIo5TGHZV_cs0fg96dlSxAERp3UaN2oC" +
      "QHIE5gQ4m5uU3ee69XfwwU_RpEIMFypycxwq1HOf4LzTLXqP_CDT8DdyX8oTwYdUB" +
      "d2d3D17Wd9UA"

    verifier = TrueLayerSigning.verify_with_pem(PUBLIC_KEY)
      .set_method(:post)
      .set_path("/foo")
      .set_body("{}")

    error = assert_raises(TrueLayerSigning::Error) { verifier.verify(tl_signature) }
    assert_equal("Invalid signature format", error.message)
  end

  def test_mismatched_signature_with_attached_valid_body_and_trailing_dots_should_fail
    # Signature for `/bar` but with a valid jws-body pre-attached.
    # If we run a simple jws verify on this unchanged, it'll work!
    tl_signature = "eyJhbGciOiJFUzUxMiIsImtpZCI6IjQ1ZmM3NWNmLTU2ND" +
      "ktndeZnC04NGIzLTE5MmMyYzc4ZTk5MCIsInRsX3ZlcnNpb24iOiIyIiwidGxfaGV" +
      "hZGVycyI6IiJ9.UE9TVCAvYmFyCnt9.ARLa7Q5b8k5CIhfy1qrS-IkNqCDeE-VFRD" +
      "z7Lb0fXUMOi_Ktck-R7BHDMXFDzbI5TyaxIo5TGHZV_cs0fg96dlSxAERp3UaN2oC" +
      "QHIE5gQ4m5uU3ee69XfwwU_RpEIMFypycxwq1HOf4LzTLXqP_CDT8DdyX8oTwYdUB" +
      "d2d3D17Wd9UA...."

    verifier = TrueLayerSigning.verify_with_pem(PUBLIC_KEY)
      .set_method(:post)
      .set_path("/foo")
      .set_body("{}")

    error = assert_raises(TrueLayerSigning::Error) { verifier.verify(tl_signature) }
    assert_equal("Invalid signature format", error.message)
  end

  def test_full_request_with_static_signature_should_succeed
    body = { currency: "GBP", max_amount_in_minor: 50_000_00, name: "Foo???" }.to_json
    idempotency_key = "idemp-2076717c-9005-4811-a321-9e0787fa0382"
    path = "/merchant_accounts/a61acaef-ee05-4077-92f3-25543a11bd8d/sweeping"
    tl_signature = File.read(File.expand_path("../../test-resources/tl-signature.txt",
                                              File.dirname(__FILE__)))

    result = TrueLayerSigning.verify_with_pem(PUBLIC_KEY)
      .set_method(:post)
      .set_path(path)
      .add_header("X-Whatever-2", "t2345d")
      .add_header("Idempotency-Key", idempotency_key)
      .set_body(body)
      .verify(tl_signature)

    refute(result.first.include?("\nX-Whatever-2: t2345d\n"))
    assert(result.first.include?("\nIdempotency-Key: " + idempotency_key + "\n"))
    assert(result.first
      .start_with?("POST /merchant_accounts/a61acaef-ee05-4077-92f3-25543a11bd8d/sweeping\n"))
  end

  def test_full_request_with_invalid_signature_should_fail
    body = { currency: "GBP", max_amount_in_minor: 50_000_00, name: "Foo???" }.to_json
    idempotency_key = "idemp-2076717c-9005-4811-a321-9e0787fa0382"
    path = "/merchant_accounts/a61acaef-ee05-4077-92f3-25543a11bd8d/sweeping"
    tl_signature = "an-invalid..signature"

    verifier = TrueLayerSigning.verify_with_pem(PUBLIC_KEY)
      .set_method(:post)
      .set_path(path)
      .add_header("X-Whatever-2", "t2345d")
      .add_header("Idempotency-Key", idempotency_key)
      .set_body(body)

    error = assert_raises(TrueLayerSigning::Error) { verifier.verify(tl_signature) }
    assert_equal("Invalid base64 for header", error.message)
  end

  def test_verify_without_signed_trailing_slash_should_succeed
    body = { foo: "bar" }.to_json

    tl_signature = TrueLayerSigning.sign_with_pem
      .set_method(:post)
      .set_path("/tl-webhook/")
      .set_body(body)
      .sign

    result = TrueLayerSigning.verify_with_pem(PUBLIC_KEY)
      .set_method(:post)
      .set_path("/tl-webhook") # different
      .set_body(body)
      .verify(tl_signature)

    assert(result.first.start_with?("POST /tl-webhook/\n"))
  end

  def test_verify_with_unsigned_trailing_slash_should_succeed
    body = { foo: "bar" }.to_json

    tl_signature = TrueLayerSigning.sign_with_pem
      .set_method(:post)
      .set_path("/tl-webhook")
      .set_body(body)
      .sign

    result = TrueLayerSigning.verify_with_pem(PUBLIC_KEY)
      .set_method(:post)
      .set_path("/tl-webhook/") # different
      .set_body(body)
      .verify(tl_signature)

    assert(result.first.start_with?("POST /tl-webhook\n"))
  end

  def test_sign_an_invalid_path_should_fail
    signer = TrueLayerSigning.sign_with_pem
    error = assert_raises(TrueLayerSigning::Error) { signer.set_path("https://example.com/path") }
    assert_equal("Path must start with '/'", error.message)
  end

  def test_verify_an_invalid_path_should_fail
    verifier = TrueLayerSigning.verify_with_pem(PUBLIC_KEY)
    error = assert_raises(TrueLayerSigning::Error) { verifier.set_path("https://example.com/path") }
    assert_equal("Path must start with '/'", error.message)
  end

  def test_full_request_signature_with_method_mismatch_should_fail
    body = { currency: "GBP", max_amount_in_minor: 50_000_00 }.to_json
    idempotency_key = "idemp-2076717c-9005-4811-a321-9e0787fa0382"
    path = "/merchant_accounts/a61acaef-ee05-4077-92f3-25543a11bd8d/sweeping"

    tl_signature = TrueLayerSigning.sign_with_pem
      .set_method(:post)
      .set_path(path)
      .add_header("Idempotency-Key", idempotency_key)
      .set_body(body)
      .sign

    verifier = TrueLayerSigning.verify_with_pem(PUBLIC_KEY)
      .set_method(:delete) # different
      .set_path(path)
      .add_header("X-Whatever", "aoitbeh")
      .add_header("Idempotency-Key", idempotency_key)
      .set_body(body)

    error = assert_raises(TrueLayerSigning::Error) { verifier.verify(tl_signature) }
    assert_equal("Signature verification failed", error.message)
  end

  def test_full_request_signature_with_path_mismatch_should_fail
    body = { currency: "GBP", max_amount_in_minor: 50_000_00 }.to_json
    idempotency_key = "idemp-2076717c-9005-4811-a321-9e0787fa0382"
    path = "/merchant_accounts/a61acaef-ee05-4077-92f3-25543a11bd8d/sweeping"

    tl_signature = TrueLayerSigning.sign_with_pem
      .set_method(:post)
      .set_path(path)
      .add_header("Idempotency-Key", idempotency_key)
      .set_body(body)
      .sign

    verifier = TrueLayerSigning.verify_with_pem(PUBLIC_KEY)
      .set_method(:post)
      .set_path("/merchant_accounts/67b5b1cf-1d0c-45d4-a2ea-61bdc044327c/sweeping") # different
      .add_header("X-Whatever", "aoitbeh")
      .add_header("Idempotency-Key", idempotency_key)
      .set_body(body)

    error = assert_raises(TrueLayerSigning::Error) { verifier.verify(tl_signature) }
    assert_equal("Signature verification failed", error.message)
  end

  def test_full_request_signature_with_header_mismatch_should_fail
    body = { currency: "GBP", max_amount_in_minor: 50_000_00 }.to_json
    idempotency_key = "idemp-2076717c-9005-4811-a321-9e0787fa0382"
    path = "/merchant_accounts/a61acaef-ee05-4077-92f3-25543a11bd8d/sweeping"

    tl_signature = TrueLayerSigning.sign_with_pem
      .set_method(:post)
      .set_path(path)
      .add_header("Idempotency-Key", idempotency_key)
      .set_body(body)
      .sign

    verifier = TrueLayerSigning.verify_with_pem(PUBLIC_KEY)
      .set_method(:post)
      .set_path(path)
      .add_header("X-Whatever", "aoitbeh")
      .add_header("Idempotency-Key", "something-else") # different
      .set_body(body)

    error = assert_raises(TrueLayerSigning::Error) { verifier.verify(tl_signature) }
    assert_equal("Signature verification failed", error.message)
  end

  def test_full_request_signature_with_body_mismatch_should_fail
    body = { currency: "GBP", max_amount_in_minor: 50_000_00 }.to_json
    idempotency_key = "idemp-2076717c-9005-4811-a321-9e0787fa0382"
    path = "/merchant_accounts/a61acaef-ee05-4077-92f3-25543a11bd8d/sweeping"

    tl_signature = TrueLayerSigning.sign_with_pem
      .set_method(:post)
      .set_path(path)
      .add_header("Idempotency-Key", idempotency_key)
      .set_body(body)
      .sign

    verifier = TrueLayerSigning.verify_with_pem(PUBLIC_KEY)
      .set_method(:post)
      .set_path(path)
      .add_header("X-Whatever", "aoitbeh")
      .add_header("Idempotency-Key", idempotency_key)
      .set_body({ max_amount_in_minor: 12_34 }.to_json) # different

    error = assert_raises(TrueLayerSigning::Error) { verifier.verify(tl_signature) }
    assert_equal("Signature verification failed", error.message)
  end

  def test_full_request_signature_missing_signed_header_should_fail
    body = { currency: "GBP", max_amount_in_minor: 50_000_00 }.to_json
    idempotency_key = "idemp-2076717c-9005-4811-a321-9e0787fa0382"
    path = "/merchant_accounts/a61acaef-ee05-4077-92f3-25543a11bd8d/sweeping"

    tl_signature = TrueLayerSigning.sign_with_pem
      .set_method(:post)
      .set_path(path)
      .add_header("Idempotency-Key", idempotency_key)
      .set_body(body)
      .sign

    verifier = TrueLayerSigning.verify_with_pem(PUBLIC_KEY)
      .set_method(:post)
      .set_path(path)
      .add_header("X-Whatever", "aoitbeh")
      # missing 'Idempotency-Key' header
      .set_body(body)

    error = assert_raises(TrueLayerSigning::Error) { verifier.verify(tl_signature) }
    assert_equal("Missing header(s) declared in signature", error.message)
  end

  def test_full_request_signature_missing_required_header_should_fail
    body = { currency: "GBP", max_amount_in_minor: 50_000_00 }.to_json
    idempotency_key = "idemp-2076717c-9005-4811-a321-9e0787fa0382"
    path = "/merchant_accounts/a61acaef-ee05-4077-92f3-25543a11bd8d/sweeping"

    tl_signature = TrueLayerSigning.sign_with_pem
      .set_method(:post)
      .set_path(path)
      .add_header("Idempotency-Key", idempotency_key)
      .set_body(body)
      .sign

    verifier = TrueLayerSigning.verify_with_pem(PUBLIC_KEY)
      .set_method(:post)
      .set_path(path)
      .require_header("X-Required") # missing from signature
      .add_header("Idempotency-Key", idempotency_key)
      .set_body(body)

    error = assert_raises(TrueLayerSigning::Error) { verifier.verify(tl_signature) }
    assert_equal("Signature missing required header(s)", error.message)
  end

  def test_full_request_signature_required_header_case_insensitive_should_succeed
    body = { currency: "GBP", max_amount_in_minor: 50_000_00 }.to_json
    idempotency_key = "idemp-2076717c-9005-4811-a321-9e0787fa0382"
    path = "/merchant_accounts/a61acaef-ee05-4077-92f3-25543a11bd8d/sweeping"

    tl_signature = TrueLayerSigning.sign_with_pem
      .set_method(:post)
      .set_path(path)
      .add_header("Idempotency-Key", idempotency_key)
      .set_body(body)
      .sign

    result = TrueLayerSigning.verify_with_pem(PUBLIC_KEY)
      .set_method(:post)
      .set_path(path)
      .require_header("IdEmPoTeNcY-KeY") # case insensitive
      .add_header("Idempotency-Key", idempotency_key)
      .set_body(body)
      .verify(tl_signature)

    assert(result.first
      .start_with?("POST /merchant_accounts/a61acaef-ee05-4077-92f3-25543a11bd8d/sweeping\n"))
  end

  def test_verify_with_flexible_header_case_and_order_should_succeed
    body = { currency: "GBP", max_amount_in_minor: 50_000_00 }.to_json
    idempotency_key = "idemp-2076717c-9005-4811-a321-9e0787fa0382"
    path = "/merchant_accounts/a61acaef-ee05-4077-92f3-25543a11bd8d/sweeping"

    tl_signature = TrueLayerSigning.sign_with_pem
      .set_method(:post)
      .set_path(path)
      .add_header("Idempotency-Key", idempotency_key)
      .add_header("X-Custom", "123")
      .set_body(body)
      .sign

    result = TrueLayerSigning.verify_with_pem(PUBLIC_KEY)
      .set_method(:post)
      .set_path(path)
      .add_header("X-CUSTOM", "123") # different case and order
      .add_header("idempotency-key", idempotency_key) # different case and order
      .set_body(body)
      .verify(tl_signature)

    assert(result.first
      .start_with?("POST /merchant_accounts/a61acaef-ee05-4077-92f3-25543a11bd8d/sweeping\n"))
  end
end
