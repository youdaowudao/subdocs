package connect

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/http"
	"time"
)

// KeyState is the outcome of GET /v1/usage for one key.
type KeyState int

const (
	KeyUsable KeyState = iota
	KeyNoBalance
	// KeyRejected is 401 or 403: the key does not exist or is blocked.
	KeyRejected
	// KeyDisabled is a 200 answer for a key the gateway refuses: isValid
	// false, or an expired or used-up key (see keyEnded).
	KeyDisabled
	// KeyTimeout: the server did not answer within usageTimeout (the
	// connection or the answer was too slow).
	KeyTimeout
	// KeyOffline: no connection at all (no network, DNS failure, refused,
	// reset, TLS failure, a proxy or firewall in the way).
	KeyOffline
	// KeyServerError: the server answered, but not with the documented
	// answer (5xx, 404, 429, a redirect or a page that is not JSON).
	KeyServerError
	// KeyClockWrong: the certificate looked expired or not yet valid. The
	// site's certificates renew themselves, so on a customer's computer
	// this means its clock is wrong (Windows PowerShell shows the same
	// failure as "未能为 SSL/TLS 安全通道建立信任关系").
	KeyClockWrong
	// KeyUntrusted: the certificate chain is not trusted: a proxy or
	// security software intercepting HTTPS, or a stripped root store.
	KeyUntrusted
)

// KeyCheck carries the remaining balance in USD when the server sent one,
// and the HTTP status for KeyServerError.
type KeyCheck struct {
	State        KeyState
	Remaining    float64
	HasRemaining bool
	StatusCode   int
}

const (
	usagePath      = "/v1/usage"
	usageTimeout   = 10 * time.Second
	maxUsageAnswer = 4 << 20
)

// NewHTTPClient never follows redirects, so the key only goes to BaseURL.
func NewHTTPClient() *http.Client {
	return &http.Client{
		Timeout: usageTimeout,
		CheckRedirect: func(*http.Request, []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}
}

// CheckKey asks the usage endpoint under baseURL about key. Production code
// always passes BaseURL; tests pass a local fake server.
func CheckKey(ctx context.Context, client *http.Client, baseURL, key string) KeyCheck {
	return checkKey(ctx, client, baseURL, key, usageTimeout)
}

func checkKey(ctx context.Context, client *http.Client, baseURL, key string, timeout time.Duration) KeyCheck {
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, baseURL+usagePath, nil)
	if err != nil {
		return KeyCheck{State: KeyOffline}
	}
	request.Header.Set("Authorization", "Bearer "+key)
	request.Header.Set("Accept", "application/json")
	request.Header.Set("User-Agent", "UseGoodAI-Quick-Connect/"+Version)
	response, err := client.Do(request)
	if err != nil {
		return networkFailure(err)
	}
	defer response.Body.Close()

	switch response.StatusCode {
	case http.StatusUnauthorized, http.StatusForbidden:
		return KeyCheck{State: KeyRejected}
	case http.StatusOK:
	default:
		return KeyCheck{State: KeyServerError, StatusCode: response.StatusCode}
	}
	var answer struct {
		IsValid   *bool           `json:"isValid"`
		Status    string          `json:"status"`
		ExpiresAt json.RawMessage `json:"expires_at"`
		Remaining *float64        `json:"remaining"`
	}
	if err := json.NewDecoder(io.LimitReader(response.Body, maxUsageAnswer)).Decode(&answer); err != nil {
		if isTimeout(err) {
			return KeyCheck{State: KeyTimeout}
		}
		return KeyCheck{State: KeyServerError, StatusCode: response.StatusCode}
	}
	if answer.IsValid == nil {
		return KeyCheck{State: KeyServerError, StatusCode: response.StatusCode}
	}
	if !*answer.IsValid || keyEnded(answer.Status, answer.ExpiresAt, time.Now()) {
		return KeyCheck{State: KeyDisabled}
	}
	if answer.Remaining == nil {
		// Some subscriptions do not report a balance; that is still usable.
		return KeyCheck{State: KeyUsable}
	}
	check := KeyCheck{State: KeyUsable, Remaining: *answer.Remaining, HasRemaining: true}
	if *answer.Remaining <= 0 {
		check.State = KeyNoBalance
	}
	return check
}

// keyEnded catches keys the gateway refuses although /v1/usage, which skips
// billing checks, still answers isValid true: a quota_limited key whose
// status is expired or quota_exhausted, or whose expires_at has passed while
// the status still says active (the status does not change when the date
// passes).
func keyEnded(status string, expiresAt json.RawMessage, now time.Time) bool {
	if status == "expired" || status == "quota_exhausted" {
		return true
	}
	var text string
	if json.Unmarshal(expiresAt, &text) != nil || text == "" {
		return false
	}
	expires, err := time.Parse(time.RFC3339Nano, text)
	return err == nil && now.After(expires)
}

// networkFailure tells a slow server (timeout) from no connection at all.
func networkFailure(err error) KeyCheck {
	if isTimeout(err) {
		return KeyCheck{State: KeyTimeout}
	}
	if state, ok := certificateFailure(err); ok {
		return KeyCheck{State: state}
	}
	return KeyCheck{State: KeyOffline}
}

// certificateFailure tells a wrong clock and an untrusted certificate apart
// from a plain network failure.
func certificateFailure(err error) (KeyState, bool) {
	var invalid x509.CertificateInvalidError
	if errors.As(err, &invalid) && invalid.Reason == x509.Expired {
		return KeyClockWrong, true
	}
	var unknown x509.UnknownAuthorityError
	var hostname x509.HostnameError
	var verification *tls.CertificateVerificationError
	if errors.As(err, &unknown) || errors.As(err, &hostname) || errors.As(err, &invalid) || errors.As(err, &verification) {
		return KeyUntrusted, true
	}
	return 0, false
}

// certificateMessage explains KeyClockWrong and KeyUntrusted with what to
// click; unchanged says what was left alone, for example "Codex 配置没有改动。".
func certificateMessage(state KeyState, now time.Time, unchanged string) string {
	if state == KeyClockWrong {
		return "电脑的日期时间不对（现在显示 " + now.Format("2006年1月2日 15:04") + "），所以连不上 UseGoodAI 服务器。" + unchanged +
			"右键任务栏右下角的时间，选「调整日期和时间」，打开「自动设置时间」并点「立即同步」，然后再点一次。"
	}
	return "电脑不信任 UseGoodAI 服务器的安全证书，常见原因是代理或安全软件在拦截加密连接，或系统太久没有更新。" + unchanged +
		"关掉代理和安全软件的「HTTPS 扫描」，或在「设置 → Windows 更新」里装完更新，然后再点一次。"
}

func isTimeout(err error) bool {
	if errors.Is(err, context.DeadlineExceeded) {
		return true
	}
	var netError net.Error
	return errors.As(err, &netError) && netError.Timeout()
}
