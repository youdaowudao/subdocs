// tls_probe 用和接入助手、生图工具相同的 Go 标准库访问网址，打印证书错误的类型，
// 看 Windows 上电脑时间不对、根证书缺失时 Go 报什么错。
package main

import (
	"crypto/tls"
	"crypto/x509"
	"errors"
	"fmt"
	"net/http"
	"os"
	"time"
)

func main() {
	client := &http.Client{Timeout: 20 * time.Second}
	for _, address := range os.Args[1:] {
		response, err := client.Get(address)
		if err == nil {
			response.Body.Close()
			fmt.Printf("GO  %-52s OK HTTP %d\n", address, response.StatusCode)
			continue
		}
		fmt.Printf("GO  %-52s ERR %s\n    %v\n", address, classify(err), err)
	}
}

func classify(err error) string {
	var unknown x509.UnknownAuthorityError
	var invalid x509.CertificateInvalidError
	var hostname x509.HostnameError
	var verification *tls.CertificateVerificationError
	switch {
	case errors.As(err, &unknown):
		return "UnknownAuthorityError"
	case errors.As(err, &invalid):
		return fmt.Sprintf("CertificateInvalidError reason=%d", invalid.Reason)
	case errors.As(err, &hostname):
		return "HostnameError"
	case errors.As(err, &verification):
		return "CertificateVerificationError"
	}
	return fmt.Sprintf("other %T", err)
}
