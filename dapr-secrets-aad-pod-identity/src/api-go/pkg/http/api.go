package http

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"

	routing "github.com/qiangxue/fasthttp-routing"
	"github.com/valyala/fasthttp"
)

const (
	applicationPort = 5000
	daprSecretURL   = "http://localhost:3500/v1.0/secrets"
	secretStoreName = "azurekeyvault"
	secretOne       = "secretone"
	secretTwo       = "secretTwo"
)

// API interface
type API interface {
	StartNonBlocking()
}

type api struct {
	router *routing.Router
	port   int
}

// NewAPI creates a new server instance
func NewAPI() API {
	api := &api{
		port:   applicationPort,
		router: routing.New(),
	}

	api.router.Get("/secret", api.onGetSecrets)
	return api
}

func (s *api) StartNonBlocking() {
	go func() {
		err := fasthttp.ListenAndServe(fmt.Sprintf(":%v", s.port), s.router.HandleRequest)
		if err != nil {
			log.Println(err)
		}
	}()
}

func (s *api) onGetSecrets(c *routing.Context) error {
	baseURL := fmt.Sprintf("%s/%s", daprSecretURL, secretStoreName)

	secretOneURL := fmt.Sprintf("%s/%s", baseURL, secretOne)
	secretTwoURL := fmt.Sprintf("%s/%s", baseURL, secretTwo)

	// query first value
	resp, err := http.Get(secretOneURL)

	if err != nil {
		c.Response.SetStatusCode(500)
		c.Response.SetBody([]byte(err.Error()))
		return err
	}

	defer resp.Body.Close()

	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		c.Response.SetStatusCode(500)
		c.Response.SetBody([]byte(err.Error()))
		return err
	}

	tmp := make(map[string]string)
	err = json.Unmarshal(body, &tmp)
	if err != nil {
		c.Response.SetStatusCode(500)
		c.Response.SetBody([]byte(err.Error()))
		return err
	}

	vauleOne := tmp[secretOne]

	// query second value
	resp2, err := http.Get(secretTwoURL)

	if err != nil {
		c.Response.SetStatusCode(500)
		c.Response.SetBody([]byte(err.Error()))
		return err
	}

	defer resp2.Body.Close()

	body2, err := ioutil.ReadAll(resp2.Body)
	if err != nil {
		c.Response.SetStatusCode(500)
		c.Response.SetBody([]byte(err.Error()))
		return err
	}

	tmp = make(map[string]string)
	err = json.Unmarshal(body2, &tmp)
	if err != nil {
		c.Response.SetStatusCode(500)
		c.Response.SetBody([]byte(err.Error()))
		return err
	}

	vauleTwo := tmp[secretTwo]

	result := fmt.Sprintf("Result from Go API: secretOne %s | secretTwo: %s", vauleOne, vauleTwo)

	c.Response.SetStatusCode(200)
	c.Response.SetBody([]byte(result))
	return nil
}
