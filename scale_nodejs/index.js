const {ClusterManagerClient} = require('@google-cloud/container').v1;
// Instantiates a client
const containerClient = new ClusterManagerClient();

async function waitForOperation(projectId,clusterId, operation) {
  while (operation.status !== 'DONE') {
    [operation] = await containerClient.getOperation({
      name: clusterId,
      operationId: operation.name,
      projectId: projectId,
      zone: operation.zone.split('/').pop(),
    });
  }
}

/**
 * Resize GKE Node Pool.
 *
 * Expects a PubSub message with JSON-formatted event data containing the
 * following attributes:
 *  zone - the GCP zone the instances are located in.
 *  cluster - cluster name.
 *  pool - node pool name to resize
 *  size - # of instances after resizing
 *
 * @param {!object} event Cloud Function PubSub message event.
 * @param {!object} callback Cloud Function PubSub callback indicating
 *  completion.
 */
exports.setSizePubSub = async (event, context, callback) => {
  try {
    const project = await containerClient.getProjectId();
    const payload = _validatePayload(event);
    const name = payload.cluster
 
    const [response] = await containerClient.setNodePoolSize({
          clusterId: payload.cluster,
          projectId: project,
          zone: payload.zone,
          name: payload.cluster,
          nodeCount: payload.size,
          nodePoolId: payload.pool
        });
        
    waitForOperation(project,payload.cluster, response);
    // Operation complete
    const message = 'Successfully resized';
    console.log(message);
    callback(null, message);
  } catch (err) {
    console.log(err);
    callback(err);
  }
};

/**
 * Validates that a request payload contains the expected fields.
 *
 * @param {!object} payload the request payload to validate.
 * @return {!object} the payload object.
 */
const _validatePayload = event => {
  let payload;
  try {
    payload = JSON.parse(Buffer.from(event.data, 'base64').toString());
  } catch (err) {
    throw new Error('Invalid Pub/Sub message: ' + err);
  }
  if (!payload.size) {
    throw new Error("Attribute 'size' missing from payload");
  } else if (!payload.zone) {
    throw new Error("Attribute 'zone' missing from payload");
  } else if (!payload.pool) {
    throw new Error("Attribute 'pool' missing from payload");
   } else if (!payload.cluster) {
    throw new Error("Attribute 'cluster' missing from payload");
  }
  return payload;
};