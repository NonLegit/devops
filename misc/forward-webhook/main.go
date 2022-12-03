package main

import (
	"bytes"
	"context"
	"io"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/aws/aws-lambda-go/events"
	runtime "github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/google/go-github/github"
)

type PayloadEvent struct {
	Path   string `json:"path"`
	Source string `json:"source"`
}

var instanceId = os.Getenv("INSTANCE_ID")
var DryRun = false

func handleRequest(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {

	// Logging all incoming requests.
	log.Printf("%v", request)
	log.Printf("%v", request.RequestContext)
	log.Printf("Body:\n%s", request.Body)

	for key, value := range request.Headers {
		log.Printf("%s = %s", key, value)
	}

	event_type := request.Headers["X-GitHub-Event"]
	content_type := request.Headers["content-type"]
	xhub_sig := request.Headers["X-Hub-Signature"]

	// Validate and parse the webhook event...
	event, err := github.ParseWebHook(event_type, []byte(request.Body))
	if err != nil {
		log.Println(err)
		return events.APIGatewayProxyResponse{StatusCode: http.StatusInternalServerError, Body: err.Error()}, nil
	}

	// Switching over the events type. The webhook is configured at github's side to only send push events, thus no need to handle any other case.
	switch event.(type) {
	case *github.PushEvent:

		// Verifying/validating the secret..
		_, err := github.ValidatePayload([]byte(request.Body), content_type, xhub_sig, []byte(os.Getenv("SECRET_KEY")))
		if err != nil {
			log.Println(err)
			return events.APIGatewayProxyResponse{StatusCode: http.StatusInternalServerError, Body: err.Error()}, nil
		}
		log.Println("receveid and validated a github webhook request")
	default:
		log.Println("unhandled github event")
		return events.APIGatewayProxyResponse{StatusCode: http.StatusInternalServerError, Body: "unhandled github event"}, nil
	}

	// Checking the status of the server.
	sess := session.Must(session.NewSession())
	ec2Client := ec2.New(sess)

	instanceStatusOutput, err := ec2Client.DescribeInstances(&ec2.DescribeInstancesInput{
		DryRun:      &DryRun,
		InstanceIds: []*string{&instanceId},
	})

	if err != nil {
		log.Println(err)
		return events.APIGatewayProxyResponse{StatusCode: http.StatusInternalServerError, Body: err.Error()}, nil
	}

	// If the instance is not running, start it (in cases of stopped/stopping states). Insert into SQS in any case and return a response.
	state := *instanceStatusOutput.Reservations[0].Instances[0].State.Name
	if !(state == "running") {

		if state == "stopped" || state == "stopping" {
			startInstanceOutput, err := ec2Client.StartInstances(&ec2.StartInstancesInput{
				DryRun:      &DryRun,
				InstanceIds: []*string{&instanceId},
			})

			if err != nil {
				log.Println(err)
				return events.APIGatewayProxyResponse{StatusCode: http.StatusInternalServerError, Body: err.Error()}, nil
			}

			startingInstance := *startInstanceOutput.StartingInstances[0]
			if *startingInstance.CurrentState.Name != "pending" {
				return events.APIGatewayProxyResponse{StatusCode: http.StatusInternalServerError, Body: "unexpected instance state"}, nil
			}
		}

		// TODO: Insert the webhook data into an SQS queue.
		return events.APIGatewayProxyResponse{StatusCode: http.StatusOK, Body: "successfully put the webhook data into sqs"}, nil
	}

	// Creating the request to be sent to jenkins
	req, err := http.NewRequest(http.MethodPost, os.Getenv("JENKINS_WEBHOOK_URL"), bytes.NewBuffer([]byte(request.Body)))
	if err != nil {
		log.Println(err)
		return events.APIGatewayProxyResponse{StatusCode: http.StatusInternalServerError, Body: err.Error()}, nil
	}

	// Setting the request headers.
	for key, value := range request.Headers {
		if strings.Contains(strings.ToLower((key)), "x-amzn") || strings.Contains(strings.ToLower((key)), "x-forwarded") || strings.Contains(key, "host") {
			continue
		} else {
			req.Header.Set(key, value)
		}
	}

	// Sending the request and printing the response..
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		log.Println(err)
		return events.APIGatewayProxyResponse{StatusCode: http.StatusInternalServerError, Body: err.Error()}, nil
	}
	defer res.Body.Close()

	resBody, err := io.ReadAll(res.Body)
	if err != nil {
		log.Println(err)
		return events.APIGatewayProxyResponse{StatusCode: http.StatusInternalServerError, Body: err.Error()}, nil
	}

	return events.APIGatewayProxyResponse{
		StatusCode:      res.StatusCode,
		Body:            string(resBody),
		IsBase64Encoded: false,
		Headers:         map[string]string{"Content-Type": res.Header.Get("Content-Type")},
	}, nil
}

func main() {
	runtime.Start(handleRequest)
}
