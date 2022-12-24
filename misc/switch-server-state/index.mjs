import { DescribeInstancesCommand, StopInstancesCommand, StartInstancesCommand } from "@aws-sdk/client-ec2";
import { ec2Client } from "./ec2Client.js"

const describeParams = {
    InstanceIds: ["$INSTANCE_ID"],
    DryRun: false
};

export const handler = async(event) => {
    
    console.log(event);
    
    const getStatusOfInstance = async() => {
        const data = await ec2Client.send(new DescribeInstancesCommand(describeParams));
        return data.Reservations[0].Instances[0].State.Name
    };

    if (event.path == '/start') {
        try {
            const state = await getStatusOfInstance();
            if (state == 'running') {
                return {
                    statusCode: 200,
                    body: JSON.stringify('already running'),
                };
            } else if (state == 'pending') {
                return {
                    statusCode: 200,
                    body: JSON.stringify('instance is already starting.. wait for a couple of minutes..')
                }
            } else if (state == 'stopping') {
                return {
                    statusCode: 200,
                    body: JSON.stringify('you can\'t start the instance while it\'s stopping. wait till it\'s in the "stopped" state')
                }
            } else {
                const data = await ec2Client.send(new StartInstancesCommand(describeParams));
                return {
                    statusCode: 200,
                    body: JSON.stringify('successfully started the instance.'),
                };
            }
        } catch(err) {
            return {
                statusCode: 500,
                body: JSON.stringify(err),
            };
        }
    } else if (event.path == '/status') {
        const state = await getStatusOfInstance();
        return {
            statusCode: 200,
            body: JSON.stringify('The state of the instance: ' + state),
        }
    } else if (event.path == '/stop') {
        try {
            const state = await getStatusOfInstance();
            if (state == 'stopped')
            {
                return {
                    statusCode: 200,
                    body: JSON.stringify("already stopped"),
                };
            } else if (state == 'stopping') {
                return {
                    statusCode: 200,
                    body: JSON.stringify("instance is stopping"),
                };
            } else if ( state == 'pending') {
                return {
                    statusCode: 200,
                    body: JSON.stringify('you cannot stop the instance while it\'s in the "pending" state. wait till it\'s in the "running" state')
                }
            } else {
                const data = await ec2Client.send(new StopInstancesCommand(describeParams));
                return {
                    statusCode: 200,
                    body: JSON.stringify('successfully stopped the instance.'),
                };
            }
        } catch(err) {
            return {
                statusCode: 500,
                body: JSON.stringify(err),
            };
        }
    } else {
        return {
            statusCode: 400,
            body: JSON.stringify("No such path."),
        };
    }
};
