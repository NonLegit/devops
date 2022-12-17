package main

import (
	"context"
	"fmt"
	"strings"

	"github.com/aws/aws-lambda-go/cfn"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/efs"
)

func RefString(v string) *string { return &v }

func changeEFSPolicy(ctx context.Context, request cfn.Event) (physicalResourceID string, data map[string]interface{}, err error) {

	sess := session.Must(session.NewSession())
	efsClient := efs.New(sess)

	efsId, ok := request.ResourceProperties["EFSId"].(string)
	if !ok {
		return request.PhysicalResourceID, map[string]interface{}{}, fmt.Errorf("error conversion")
	}

	if request.RequestType == cfn.RequestDelete {
		_, err := efsClient.DeleteFileSystemPolicy(&efs.DeleteFileSystemPolicyInput{
			FileSystemId: &efsId,
		})

		if err != nil {
			return request.PhysicalResourceID, map[string]interface{}{}, fmt.Errorf("error deleting the policy")
		}

		return request.PhysicalResourceID, map[string]interface{}{}, nil
	}

	policyJson := "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"allow-ec2-instance\",\"Effect\":\"Allow\",\"Principal\":{\"AWS\":\"$EC2_ROLE_ARN\"},\"Action\":[\"elasticfilesystem:ClientMount\",\"elasticfilesystem:ClientWrite\"],\"Resource\":\"$EFS_ARN\",\"Condition\":{\"StringEquals\":{\"elasticfilesystem:AccessPointArn\":\"$ACCESS_POINT_ARN\"},\"Bool\":{\"elasticfilesystem:AccessedViaMountTarget\":\"true\"}}},{\"Sid\":\"DenyNonsecureAccess\",\"Effect\":\"Deny\",\"Principal\":{\"AWS\":\"*\"},\"Action\":\"*\",\"Resource\":\"$EFS_ARN\",\"Condition\":{\"Bool\":{\"aws:SecureTransport\":\"false\"}}}]}"

	policyJson = strings.Replace(policyJson, "$EFS_ARN", request.ResourceProperties["EFSArn"].(string), -1)
	policyJson = strings.Replace(policyJson, "$ACCESS_POINT_ARN", request.ResourceProperties["AccessPointArn"].(string), -1)
	policyJson = strings.Replace(policyJson, "$EC2_ROLE_ARN", request.ResourceProperties["EC2RoleArn"].(string), -1)

	_, err = efsClient.PutFileSystemPolicy(&efs.PutFileSystemPolicyInput{
		FileSystemId: &efsId,
		Policy:       &policyJson,
	})

	if err != nil {
		return request.PhysicalResourceID, map[string]interface{}{}, fmt.Errorf("error putting the policy")
	}

	return request.PhysicalResourceID, map[string]interface{}{}, nil

}

func main() {
	lambda.Start(cfn.LambdaWrap(changeEFSPolicy))
}
