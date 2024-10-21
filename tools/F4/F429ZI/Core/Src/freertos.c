/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * File Name          : freertos.c
  * Description        : Code for freertos applications
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2024 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  *
  ******************************************************************************
  */
/* USER CODE END Header */

/* Includes ------------------------------------------------------------------*/
#include "FreeRTOS.h"
#include "task.h"
#include "main.h"
#include "cmsis_os.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */
#include <stdbool.h>
#include <rcl/rcl.h>
#include <rcl/error_handling.h>
#include <rclc/rclc.h>
#include <rclc/executor.h>
#include <uxr/client/transport.h>
#include <rmw_microxrcedds_c/config.h>
#include <rmw_microros/rmw_microros.h>

#include <sensor_msgs/msg/joint_state.h>
#include <std_msgs/msg/int32.h>
#include "usart.h"
#include "can.h"
#include "lwip.h"
/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */

/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */
#define TS 50

#define max(a,b)             \
({                           \
    __typeof__ (a) _a = (a); \
    __typeof__ (b) _b = (b); \
    _a > _b ? _a : _b;       \
})

#define min(a,b)             \
({                           \
    __typeof__ (a) _a = (a); \
    __typeof__ (b) _b = (b); \
    _a < _b ? _a : _b;       \
})

#ifndef ETH_TX_DESC_CNT
#define ETH_TX_DESC_CNT         4U
#endif /* ETH_TX_DESC_CNT */

#ifndef ETH_RX_DESC_CNT
#define ETH_RX_DESC_CNT         4U
#endif /* ETH_RX_DESC_CNT */

/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/
/* USER CODE BEGIN Variables */
int i = 50;

rcl_subscription_t subscriber;
rcl_publisher_t publisher;
/* USER CODE END Variables */
/* Definitions for defaultTask */
osThreadId_t defaultTaskHandle;
const osThreadAttr_t defaultTask_attributes = {
  .name = "defaultTask",
  .stack_size = 3000 * 4,
  .priority = (osPriority_t) osPriorityNormal,
};

/* Private function prototypes -----------------------------------------------*/
/* USER CODE BEGIN FunctionPrototypes */
bool cubemx_transport_open(struct uxrCustomTransport * transport);
bool cubemx_transport_close(struct uxrCustomTransport * transport);
size_t cubemx_transport_write(struct uxrCustomTransport* transport, const uint8_t * buf, size_t len, uint8_t * err);
size_t cubemx_transport_read(struct uxrCustomTransport* transport, uint8_t* buf, size_t len, int timeout, uint8_t* err);

void * microros_allocate(size_t size, void * state);
void microros_deallocate(void * pointer, void * state);
void * microros_reallocate(void * pointer, size_t size, void * state);
void * microros_zero_allocate(size_t number_of_elements, size_t size_of_element, void * state);

#ifdef __GNUC__
#define PUTCHAR_PROTOTYPE int __io_putchar(int ch)
#else
#define PUTCHAR_PROTOTYPE int fputc(int ch, FILE *f)
#endif

PUTCHAR_PROTOTYPE
{
  HAL_UART_Transmit(&huart3, (uint8_t *)&ch, 1, HAL_MAX_DELAY);
  return ch;
}

void subscription_callback(const void *);

/* USER CODE END FunctionPrototypes */

void StartDefaultTask(void *argument);

extern void MX_LWIP_Init(void);
void MX_FREERTOS_Init(void); /* (MISRA C 2004 rule 8.1) */

/**
  * @brief  FreeRTOS initialization
  * @param  None
  * @retval None
  */
void MX_FREERTOS_Init(void) {
  /* USER CODE BEGIN Init */

  /* USER CODE END Init */

  /* USER CODE BEGIN RTOS_MUTEX */
  /* add mutexes, ... */
  /* USER CODE END RTOS_MUTEX */

  /* USER CODE BEGIN RTOS_SEMAPHORES */
  /* add semaphores, ... */
  /* USER CODE END RTOS_SEMAPHORES */

  /* USER CODE BEGIN RTOS_TIMERS */
  /* start timers, add new ones, ... */
  /* USER CODE END RTOS_TIMERS */

  /* USER CODE BEGIN RTOS_QUEUES */
  /* add queues, ... */
  /* USER CODE END RTOS_QUEUES */

  /* Create the thread(s) */
  /* creation of defaultTask */
  defaultTaskHandle = osThreadNew(StartDefaultTask, NULL, &defaultTask_attributes);

  /* USER CODE BEGIN RTOS_THREADS */
  /* add threads, ... */
  //TaskHandle = osThreadNew(publisherandsubscriber, NULL, &Task_attributes);
  /* USER CODE END RTOS_THREADS */

  /* USER CODE BEGIN RTOS_EVENTS */
  /* add events, ... */
  /* USER CODE END RTOS_EVENTS */

}

/* USER CODE BEGIN Header_StartDefaultTask */
/**
  * @brief  Function implementing the defaultTask thread.
  * @param  argument: Not used
  * @retval None
  */
/* USER CODE END Header_StartDefaultTask */
void StartDefaultTask(void *argument)
{
  /* init code for LWIP */
  MX_LWIP_Init();
  /* USER CODE BEGIN StartDefaultTask */
  	rcl_ret_t ret;
	ret = rmw_uros_set_custom_transport(
		true,
		(void *) &huart3,         //change in you want a different type of comunication for ros2-agent
		cubemx_transport_open,
		cubemx_transport_close,
		cubemx_transport_write,
		cubemx_transport_read);

	if (ret != RCL_RET_OK)
	{
	    printf("Error setting custom transport");
	    //return;
	}

	rcl_allocator_t freeRTOS_allocator = rcutils_get_zero_initialized_allocator();
	freeRTOS_allocator.allocate = microros_allocate;
	freeRTOS_allocator.deallocate = microros_deallocate;
	freeRTOS_allocator.reallocate = microros_reallocate;
	freeRTOS_allocator.zero_allocate =  microros_zero_allocate;

	if (!rcutils_set_default_allocator(&freeRTOS_allocator))
	{
	  printf("Error on default allocators (line %d)\n", __LINE__);
	}

	// micro-ROS app

	std_msgs__msg__Int32 msg;

	rclc_support_t support;
	rcl_allocator_t allocator;
	//rcl_node_t node1;
	rcl_node_t node;


	allocator = rcl_get_default_allocator();

	//create init_options
	ret = rclc_support_init(&support, 0, NULL, &allocator);
	if(ret != RCL_RET_OK)
	{
	    printf("Error initializing support");
	    return;
	}

	// create node
	//rclc_node_init_default(&node1, "cubemx_node1", "", &support);
	ret = rclc_node_init_default(&node, "cubemx_node", "", &support);
	if(ret!= RCL_RET_OK)
	{
		printf("Error on node_init_default (line %d)\n", __LINE__);
		return;
	}

	// create publisher
	ret = rclc_publisher_init_default(
	  &publisher,
	  &node,
	  ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, Int32),
	  "cubemx_publisher");
	if(ret != RCL_RET_OK)
	{
		printf("Error on publisher_init_default (line %d)\n", __LINE__);
		return;
	}

	ret = rclc_subscription_init_default(
	  &subscriber,
	  &node,
	  ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, Int32),
	  "cubemx_subscriber");
	if(ret != RCL_RET_OK)
	{
		printf("Error on subscription_init_default (line %d)\n", __LINE__);
		return;
	}

	rclc_executor_t executor = rclc_executor_get_zero_initialized_executor();
	ret = rclc_executor_init(&executor, &support.context, 1, &allocator);
	if(ret != RCL_RET_OK)
	{
		printf("Error on executor_init (line %d)\n", __LINE__);
		return;
	}

	ret = rclc_executor_add_subscription(&executor, &subscriber, &msg, &subscription_callback, ON_NEW_DATA);
	if(ret != RCL_RET_OK)
	{
		printf("Error on executor_add_subscription (line %d)\n", __LINE__);
		return;
	}


	//rclc_subscriber_init_default

	for(;;)
	{
		ret = rclc_executor_spin_some(&executor, RCL_MS_TO_NS(1000));  // timeout di 100 ms
		if(ret != RCL_RET_OK)
		{
			printf("Error in executor spin_some (line %d)\n", __LINE__);
			return;
		}
		//HAL_Delay(100);
	}
  /* USER CODE END StartDefaultTask */
}

/* Private application code --------------------------------------------------*/
/* USER CODE BEGIN Application */
void subscription_callback(const void *msgin)
{
	rcl_ret_t ret;
	const std_msgs__msg__Int32 *msg = (const std_msgs__msg__Int32 *)msgin;
	
	msg1.data = msg->data;
	//msg->data = (uint32_t)rx;

	ret = rcl_publish(&publisher, &msg1, NULL);
	if (ret != RCL_RET_OK)
	{
		printf("Error publishing (line %d)\n", __LINE__);
	}

	//printf("Received: %d\n", msg->data);
}


/* USER CODE END Application */

