---
layout: post
title: "[WIP] The tester pattern in react"
description: "Explorint the testern pattern in a react project"
category: "develop"
tags: ["javascript", "typescript", "react", "vite", "react-testing-library"]
---

The [tester pattern](https://www.testerpattern.nl/pattern) is a good way to structure your tests to improve the readability and to make very easy to write and expand the test suite.

In the original webpage, the author explain the concepts in java, in this blog we will try the pattern in JavaScript, more specifically in a react SPA.

The libraries that we will be using are:

- vitest as the runner and mock library
- react testing library to interact with react components.

Let's explore the pattern in various examples with an increase level of
complexity:


- a simple component that draws a static message
- a form with various inputs.
- the same component, but the message is a quote from a web service. Using MSW for the test.


# first scenario: simple component

Let's test this component:

```tsx
export const HelloWorld = (props) => (
    <div>
        Hello {props.name}
    </div>
)
```

To test the rendering of this component, we can this test:

```tsx
describe('simpleComponent', () => {
    it('renderAndUpdateGreeting', async () => {
        const tester = new HelloWorldPageTester()
                           .withName('Arturo');
        
        let asserter = await tester.whenRender();
        await asserter.hasText("Hello Arturo");

        tester.withName('Volpe');
        asserter = await tester.whenRerender();
        await asserter.hasText("Hello Volpe");
    });
});
```

For this simple case the boilerplate of adding a tester and asserter helper
classes may be too much, but an interesting side-effect is that the test doesn't
have any component-related selector.

The test is in 'plain' english (with the limitation of the language) and the helper classes can be user for multiple tests.

The tester and asserted used:

```tsx
class HelloWorldPageTester {

    name: String = "";
    component!: RenderResult;

    withName(name: string) { this.name = name; return this; }

    whenRender() {
        this.component = render(<HelloWorld name={this.name} />);
        return new HelloWorldPageAsserter(this.component);
    }

    whenRerender() {
        this.component.rerender(<HelloWorld name={this.name} />);
        return new HelloWorldPageAsserter(this.component);
    }
}

class HelloWorldPageAsserter {
    constructor(private component: RenderResult) {}

    async hasText(expectedText: string) {
        await this.component.findByText(expectedText);
        return this;
    }
}
```


## A note about async/await

Ideally we want a fluent syntax when using the tester pattern, for example in
Java we can have a bunch of asserts chained:

```java
new BookTester()
    .givenAuthor("Arturo Volpe")
    .givenHasChapter("1 - VITE")
    .givenHasChapter("2 - The pattern")
    .whenPublish() // return asserter
    .thenHasInCover("Author: Arturo Volpe")
    .thenHasInChapters(2);
```

To map this to a `react-testing-library` test, we need to use async/await,
normally the asserter methods are required to be async in order to use the
[findBy
methods](https://testing-library.com/docs/dom-testing-library/api-async#findby-queries),
so we need to migrate to:

```typescript
const tester = new BookComponentTester()
                    .givenAuthor("Arturo Volpe")
                    .givenHasChapter("1 - VITE")
                    .givenHasChapter("2 - The pattern");

// normally here we render/fill the 'page'
const asserter = await tester.whenRender();

await asserter.thenHasInCover("Author: Arturo Volpe");
await asserter.thenHasInChapters(2);
```

Maybe if someday the [pipeline
operator](https://github.com/tc39/proposal-pipeline-operator?tab=readme-ov-file)
added to the language, this will be more concise:

```typescript
new BookComponentTester()
   .givenAuthor("Arturo Volpe")
   .givenHasChapter("1 - VITE")
   .givenHasChapter("2 - The pattern")
   // normally here we render/fill the 'page'
   |> await %.whenRender()
   |> await %.thenHasInCover("Author: Arturo Volpe")
   |> await %.thenHasInChapters(2)
```

# Second scenario: A simple form

The tester pattern realy shines when we need to test different use cases that
has a similar setup and need specific assertions, in this case we will have a
form to edit some personal information (name and lastname).

For the form we will use
[react-hook-form](https://react-hook-form.com/get-started), and the [getting
started page](https://react-hook-form.com/get-started) form with some small
modifications.

In this form, we have two inputs:

* name: the first name, required, max length 10
* lastname: the last name, not required, max length 20

```tsx
type Inputs = {
  lastname: string
  firstname: string
}

export function Step2Form(props: {
    onSubmit: (dat: Inputs) => void
}) {
  const {
    register,
    handleSubmit,
    watch,
    formState: { errors },
  } = useForm<Inputs>()
    const onSubmit: SubmitHandler<Inputs> = (data) => props.onSubmit(data); 

    return <form onSubmit={handleSubmit(onSubmit)}>

        <input {...register("firstname", { required: true, maxLength: 10 })} data-testid="firstname-input"/>
        {errors.firstname 
            ? <span>This field is invalid</span>
            : <span>The firstname is valid</span>
        }

        <input {...register("lastname", { maxLength: 20 })} data-testid="lastname-input"/>

        <span>The form has {Object.keys(errors).length} errors</span>
        <input type="submit" data-testid="step2-button" value="Save" />
    </form>

}
```

> Some spans are added to make the test easier to write, in the real world, 
those messages may appear under the inputs or in other parts of the form, the
`data-testid` may be replaced with `findByRole`, etc.

Ideally we want very descriptive tests for this form, an easy way to write all
the different cases, required fields, invalid lengths, etc, lets start with a
simple test that check that the 'happy path' works:

```tsx
describe('step2Form', () => {
    it('renderValidValues', async () => {
        const tester = new Step2FormPageTester()
            .withName('Arturo')
            .withLastname('Volpe');
        
        let asserter = await tester.whenDoSubmit();
        await asserter.hasAllFieldsValid();
    });
});
```

In this test we create a tester that populates both fields and clicks the
button, in this case the tester is like a robot, we give the tester some
instructions, and the tester execute the required steps.

Reading this test we don't know anything about the internals of the component,
we only know that we are asking the tester to submit the form with a given name
and lastname. **The internals of the component and the complexity of the
emulation of user actions is hidden to the test, making it easy to read and 
follow**.

The tester for this form is slightly more complex:

```tsx
class Step2FormPageTester {

    name: String = "";
    lastname: String = "";
    component!: RenderResult;

    withName(name: string) { this.name = name; return this; }
    withLastname(lastname: string) { this.lastname = lastname; return this; }

    async whenDoSubmit() {
        this.component = render(<Step2Form onSubmit={this.submitCallback} />);

        await this.fillInput("firstname-input", this.name);
        await this.fillInput("lastname-input", this.lastname);

        return new Step2FormPageAsserter(this.component, this.submitCallback);
    }

    async fillInput(targetTestId: string, toInsert: string) {
        const input = await this.component.findByTestId(targetTestId);
        fireEvent.change(input, {target: {value: toInsert}})
        return this;
    }

}

class Step2FormPageAsserter {
    constructor(private component: RenderResult,
                private callback: (dat: Inputs) => void) {}

    async hasText(expectedText: string) {
        await this.component.findByText(expectedText);
        return this;
    }

    async hasAllFieldsValid() {
        return this.hasText('The form has 0 errors');
    }
}
```

We can see that there are some 'component kwnoledge' in the Tester, the tester
knows how to find the desired inputs, and that logic, specially when we are
testing front end components is very tricky, sometimes we need to wait it to
render, sometimes we need to use a complex css selector, but all of that is
hidden and is a implementation detail of the Tester.

## Adding more tests cases

Once we write the tester, adding more scenarios is trivial:

```tsx
    it('validateEmptyFields', async () => {
        const tester = new Step2FormPageTester()
            .withName('')
            .withLastname('');
        
        let asserter = await tester.whenDoSubmit();
        await asserter.hasInvalidFieldsCount(1); // only the name is required
        await asserter.hasInvalidFirstName();
    });

    it('validateInvalidFields', async () => {
        const tester = new Step2FormPageTester()
            .withName('super large name that exceed the expected length')
            .withLastname('super large lastname that exceed the expected length');
        
        let asserter = await tester.whenDoSubmit();
        await asserter.hasInvalidFieldsCount(2);
        await asserter.hasInvalidFirstName();
    });
```

Adding two new tests only required two new assertions:

```tsx
// FormAsserter
    async hasInvalidFieldsCount(expectedCount: number) {
        return this.hasText(`The form has ${expectedCount} errors`);
    }

    async hasInvalidFirstName() {
        return this.hasText(`This field is invalid`);
    }
```

Using the tester pattern, adding more tests is easy once we have the tester and
the asserter with many features.

## An extra complexity, verifying the invocation to the callback

The `Step2Form` component receives a callback as a property, this callback is
invoked only when the form is valid, the first argument of the function is the
valid object.

To verify that the function is only called when we have a valid form, we need 
to mock a call, lets do that in the Tester:

```tsx
class Step2FormPageTester {

    // ...
    submitCallback: (dat: Inputs) => void = vi.fn();
    // ...

    async whenDoSubmit() {
        // .. same as before

        const bttn = await this.component
                .findByText('Save');

        fireEvent.click(bttn);

        return new Step2FormPageAsserter(this.component, this.submitCallback);
    }
```

> Here we can have two differente asserts, one to check for contents in the 
page, and another one to assert the invocations to the function. For simplicity,
we will only use one.

With this mock (`vn.fn()`) function, we can add assertions:

```tsx
class Step2FormPageAsserter {
    constructor(private component: RenderResult,
                private callback: (dat: Inputs) => void) {}

    // ...

    async callbackWasNotCalled() {
        expect(this.callback).toHaveBeenCalledTimes(0);
        return this;
    }

    async callbackWasCalledWith(expected: Inputs) {
        expect(this.callback).toHaveBeenCalledWith(expected);
        return this;
    }
}
```

And modify the tests:

```tsx
    it('renderValidValues', async () => {
        const tester = new Step2FormPageTester()
            .withName('Arturo')
            .withLastname('Volpe');
        
        let asserter = await tester.whenDoSubmit();
        await asserter.hasAllFieldsValid();
        await asserter.callbackWasCalledWith({
            firstname: 'Arturo',
            lastname: 'Volpe'
        });
    });
    it('validateEmptyFields', async () => {
        const tester = new Step2FormPageTester()
            .withName('')
            .withLastname('');
        
        let asserter = await tester.whenDoSubmit();
        await asserter.hasInvalidFieldsCount(1);
        await asserter.hasInvalidFirstName();
        await asserter.callbackWasNotCalled();
    });
```
