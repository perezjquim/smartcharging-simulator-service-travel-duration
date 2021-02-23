from nameko.events import EventDispatcher
from nameko.rpc import rpc

from model.exceptions import NotFound

import json

import tensorflow as tf

class ModelService:

    TRAVEL_DURATION_AVG = 80 #DUMMY VALUE
    TRAVEL_DURATION_STDDEV = 20 #DUMMY VALUE

    name = 'model_energysim_travel_duration'

    event_dispatcher = EventDispatcher( )

    @rpc
    def get_duration( self ):
        travel_duration = self.generate_duration( )
        response = json.dumps( { 'travel_duration': travel_duration } )
        return response

    def generate_duration( self ):
        shape = [ 1,1 ]
        
        min_travel_duration = ModelService.TRAVEL_DURATION_AVG - ModelService.TRAVEL_DURATION_STDDEV
        max_travel_duration = ModelService.TRAVEL_DURATION_AVG + ModelService.TRAVEL_DURATION_STDDEV

        tf_random = tf.random.uniform(
                shape=shape,
                minval=min_travel_duration,
                maxval=max_travel_duration,
                dtype=tf.dtypes.float32,
                seed=None,
                name=None
        )
        tf_var = tf.Variable( tf_random )

        tf_init = tf.compat.v1.global_variables_initializer( )
        tf_session = tf.compat.v1.Session( )
        tf_session.run( tf_init )

        tf_return = tf_session.run( tf_var )
        travel_duration = float( tf_return[ 0 ][ 0 ] )

        return travel_duration
