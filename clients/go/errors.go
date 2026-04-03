package dotprompt

import "fmt"

type DotPromptError struct {
	Message string
}

func (e *DotPromptError) Error() string {
	return e.Message
}

type ConnectionError struct {
	Message string
}

func (e *ConnectionError) Error() string {
	return e.Message
}

type TimeoutError struct {
	Message string
}

func (e *TimeoutError) Error() string {
	return e.Message
}

type ServerError struct {
	StatusCode int
	Message    string
}

func (e *ServerError) Error() string {
	return fmt.Sprintf("Server Error (%d): %s", e.StatusCode, e.Message)
}

type APIClientError struct {
	StatusCode int
	Message    string
}

func (e *APIClientError) Error() string {
	return fmt.Sprintf("API Client Error (%d): %s", e.StatusCode, e.Message)
}

type MissingRequiredParamsError struct {
	Message string
}

func (e *MissingRequiredParamsError) Error() string {
	return e.Message
}

type PromptNotFoundError struct {
	PromptName string
	Message    string
}

func (e *PromptNotFoundError) Error() string {
	return fmt.Sprintf("Prompt not found: %s", e.PromptName)
}

type ValidationError struct {
	Message string
}

func (e *ValidationError) Error() string {
	return e.Message
}
