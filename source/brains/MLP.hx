package brains;

import utilities.HxFuncs;
import flixel.FlxG;

/**
 * MultiLayer Perceptron.
 */
class MLP {
	/**
	 * How many input neurons this network has.
	 * 
	 * This is set when the network is first created.
	 */
	public var inputLayerSize(default, null):Int;

	/**
	 * The perceptron's hidden layer.
	 */
	public var hiddenLayer(default, null):Array<Float>;

	/**
	 * Array of outputs processed by the hidden layer.
	 */
	public var hiddenOutputs(default, null):Array<Float>;

	/**
	 * The perceptron's hidden layer.
	 */
	public var outputLayer(default, null):Array<Float>;

	/**
	 * Array of outputs processed by the output layer.
	 */
	public var outputOutputs(default, null):Array<Float>;

	/**
	 * Array of connections for the connections between neurons.
	 */
	public var connections(default, null):Array<Float>;

	/**
	 * Total number of connection connections.
	 *
	 * Calculated by doing the sum between:
	 * - number of connections between input and hidden layers: `input neurons * hidden neurons`
	 * - number of connections between hidden and output layers: `hidden neurons * output neurons`
	 */
	public var connectionsCount(default, null):Int;

	/**
	 * Creates a new `MLP` instance and initializes each neuron to random values between -1 and 1 inclusive.
	 * 
	 * All of the `connections` (connections) between neurons are also randomly generated.
	 * 
	 * @param _inputLayerSize the number of neurons that the `inputLayer` will have
	 * @param _hiddenLayerSize the number of neurons that the `hiddenLayer` will have
	 * @param _outputLayerSize the number of neurons that the `outputLayer` will have
	 */
	public function new(_inputLayerSize:Int, _hiddenLayerSize:Int, _outputLayerSize:Int) {
		// calculate number of connection connections between neurons and initialise them with random values
		connectionsCount = (_inputLayerSize * _hiddenLayerSize) + (_hiddenLayerSize * _outputLayerSize);
		connections = [for (i in 0...connectionsCount) FlxG.random.float(-1, 1)];

		inputLayerSize = _inputLayerSize;
		// initialise layers of neurons
		hiddenLayer = [for (i in 0..._hiddenLayerSize) FlxG.random.float(-1, 1)];
		outputLayer = [for (i in 0..._outputLayerSize) FlxG.random.float(-1, 1)];
		// initialise lists of outputs with 0s
		hiddenOutputs = [for (i in 0..._hiddenLayerSize) 0];
		outputOutputs = [for (i in 0..._outputLayerSize) 0];
	}

	/**
	 * Feed the input forward through the network.
	 * 
	 * Optimize with matrix multiplication in the future if needed.
	 * Remeber to add bias (last input neuron always on 1) for when all inputs are 0es.
	 * 
	 * @param _inputLayer the input data that the network will process, values must be between 0 and 1
	 * @return the array of outputs produced by the network, each output ranging from -1 to 1 inclusive
	 */
	public function feedForward(_inputLayer:Array<Float>):Array<Float> {
		// convert inputLayer range from 0..1 to -1..1
		_inputLayer = [for (input in _inputLayer) HxFuncs.map(input, 0, 1, -1, 1)];

		var cc:Int = 0; // connections counter

		for (i in 0...hiddenLayer.length) {
			var sum:Float = 0;
			for (j in 0..._inputLayer.length) {
				sum += _inputLayer[j] * connections[cc++];
			}
			hiddenOutputs[i] = HxFuncs.tanh(sum);
		}

		for (i in 0...outputLayer.length) {
			var sum:Float = 0;
			for (j in 0...hiddenOutputs.length) {
				sum += hiddenOutputs[j] * connections[cc++];
			}
			outputOutputs[i] = HxFuncs.tanh(sum);
		}

		return outputOutputs;
	}
}

/**
 * Check to prove genetic material is correctly encoded
 */
class Test {
	static function main() {
		var _inputLayerSize = 32;
		var _hiddenLayerSize = 4;
		var hiddenLayer = [for (i in 0..._hiddenLayerSize) "h"];

		var _outputLayerSize = 4;
		var outputLayer = [for (i in 0..._outputLayerSize) "o"];

		var connectionsCount = (_inputLayerSize * hiddenLayer.length) + (hiddenLayer.length * outputLayer.length);
		var connections = [for (i in 0...connectionsCount) "w"];

		var geneticMaterial = hiddenLayer.concat(outputLayer);
		geneticMaterial = geneticMaterial.concat(connections);

		trace(geneticMaterial);
	}
}
